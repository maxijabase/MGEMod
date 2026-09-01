
// ===== GLICKO-2 RATING ENGINE =====
//
// Opt-in rating engine (mgemod_rating_engine "glicko2"). Implements Glickman's published
// Glicko-2 algorithm: http://www.glicko.net/glicko/glicko2.pdf
//
// Ratings are stored on the same 1500-centered, ~400-scale as Elo (mgemod_stats.rating,
// reused as-is) so both engines share one column and one leaderboard. RD and volatility
// are the two new nullable columns added by migration 007. Their nullability is a strict
// engine signal, never ambiguous: NULL means Elo is active, non-NULL means Glicko-2 is
// active - even for a player who has never played a single Glicko-2 duel. New rows get
// rd=350/volatility=0.06 immediately (GetInsertPlayerQuery), migration 008 backfills rows
// that predate this, and handler_ConVarChange re-syncs both directions if the engine is
// ever flipped at runtime. Glicko2_EnsureSeeded below is just an in-memory safety net for
// the rare case a connected client's cache disagrees with what's on disk.

// Seeds a player's RD/volatility on first contact with the Glicko-2 engine.
// Their rating is left untouched (Elo value, or DEFAULT_STARTING_ELO for new players).
void Glicko2_EnsureSeeded(int client)
{
    if (g_bPlayerGlickoSeeded[client])
        return;

    g_fPlayerRD[client] = GLICKO2_MAX_RD;
    g_fPlayerVolatility[client] = GLICKO2_DEFAULT_VOLATILITY;
    g_bPlayerGlickoSeeded[client] = true;
}

// Inflates RD to reflect uncertainty accumulated while the player wasn't playing,
// following Glickman's step 1 (applied once for every full rating period skipped).
void Glicko2_ApplyInactivityDecay(int client, int now)
{
    if (g_iPlayerLastPlayed[client] <= 0 || g_fGlickoPeriodDays <= 0.0)
        return;

    float periodSeconds = g_fGlickoPeriodDays * 86400.0;
    int elapsedPeriods = RoundToFloor(float(now - g_iPlayerLastPlayed[client]) / periodSeconds);
    if (elapsedPeriods <= 0)
        return;

    float phi = g_fPlayerRD[client] / GLICKO2_SCALE;
    float sigma = g_fPlayerVolatility[client];
    float inflatedPhi = SquareRoot((phi * phi) + (float(elapsedPeriods) * sigma * sigma));

    float maxPhi = GLICKO2_MAX_RD / GLICKO2_SCALE;
    if (inflatedPhi > maxPhi)
        inflatedPhi = maxPhi;

    g_fPlayerRD[client] = inflatedPhi * GLICKO2_SCALE;
}

// g(phi): discounts an opponent's rating impact by their own uncertainty.
float Glicko2_G(float phi)
{
    return 1.0 / SquareRoot(1.0 + ((3.0 * phi * phi) / (GLICKO2_PI * GLICKO2_PI)));
}

// E(mu, mu_j, phi_j): expected score against an opponent.
float Glicko2_E(float mu, float otherMu, float otherPhi)
{
    return 1.0 / (1.0 + Pow(GLICKO2_E, -Glicko2_G(otherPhi) * (mu - otherMu)));
}

// f(x): the function whose root is the new volatility (in ln(variance) space).
// Solved below via the Illinois algorithm, per Glickman's step 5.
float Glicko2_F(float delta, float phi, float v, float x, float a, float tau)
{
    float ex = Pow(GLICKO2_E, x);
    float num = ex * ((delta * delta) - (phi * phi) - v - ex);
    float den = 2.0 * Pow((phi * phi) + v + ex, 2.0);
    return (num / den) - ((x - a) / (tau * tau));
}

// Inflates RD by one rating period with no games (Glickman step 6, no-game case).
void Glicko2_InflateRdOnePeriod(float rd, float volatility, float &newRd)
{
    float phi = rd / GLICKO2_SCALE;
    float inflatedPhi = SquareRoot((phi * phi) + (volatility * volatility));
    float maxPhi = GLICKO2_MAX_RD / GLICKO2_SCALE;
    if (inflatedPhi > maxPhi)
        inflatedPhi = maxPhi;
    newRd = inflatedPhi * GLICKO2_SCALE;
}

// Pure Glicko-2 update for one rating period against any number of opponents.
// One phiStar, v and Δ as sums over the period. Display-scale in/out. No global writes.
void Glicko2_ComputePeriodUpdate(float rating, float rd, float volatility, int gameCount,
    const float[] oppRating, const float[] oppRd, const float[] score,
    float &newRating, float &newRd, float &newVolatility)
{
    if (gameCount <= 0)
    {
        newRating = rating;
        newRd = rd;
        newVolatility = volatility;
        return;
    }

    float mu = (rating - 1500.0) / GLICKO2_SCALE;
    float phi = rd / GLICKO2_SCALE;
    float sigma = volatility;

    float vInv = 0.0;
    float deltaSum = 0.0;

    for (int i = 0; i < gameCount; i++)
    {
        float oppMu = (oppRating[i] - 1500.0) / GLICKO2_SCALE;
        float oppPhi = oppRd[i] / GLICKO2_SCALE;
        float g = Glicko2_G(oppPhi);
        float e = Glicko2_E(mu, oppMu, oppPhi);
        if (e < 0.0001)
            e = 0.0001;
        else if (e > 0.9999)
            e = 0.9999;
        vInv += g * g * e * (1.0 - e);
        deltaSum += g * (score[i] - e);
    }

    if (vInv <= 0.0)
    {
        newRating = rating;
        Glicko2_InflateRdOnePeriod(rd, volatility, newRd);
        newVolatility = volatility;
        return;
    }

    float v = 1.0 / vInv;
    float delta = v * deltaSum;

    float a = Logarithm(sigma * sigma, GLICKO2_E);
    float tau = g_fGlickoTau;

    float A = a;
    float B;
    if ((delta * delta) > (phi * phi) + v)
    {
        B = Logarithm((delta * delta) - (phi * phi) - v, GLICKO2_E);
    }
    else
    {
        int k = 1;
        B = a - (float(k) * tau);
        while (Glicko2_F(delta, phi, v, B, a, tau) < 0.0)
        {
            k++;
            B = a - (float(k) * tau);
        }
    }

    float fA = Glicko2_F(delta, phi, v, A, a, tau);
    float fB = Glicko2_F(delta, phi, v, B, a, tau);

    int iterations = 0;
    while (FloatAbs(B - A) > GLICKO2_CONVERGENCE_EPSILON && iterations < 100)
    {
        float C = A + (((A - B) * fA) / (fB - fA));
        float fC = Glicko2_F(delta, phi, v, C, a, tau);

        if ((fC * fB) < 0.0)
        {
            A = B;
            fA = fB;
        }
        else
        {
            fA = fA / 2.0;
        }

        B = C;
        fB = fC;
        iterations++;
    }

    float newSigma = Pow(GLICKO2_E, A / 2.0);
    float phiStar = SquareRoot((phi * phi) + (newSigma * newSigma));
    float newPhi = 1.0 / SquareRoot((1.0 / (phiStar * phiStar)) + (1.0 / v));
    float newMu = mu + ((newPhi * newPhi) * deltaSum);

    newRating = (newMu * GLICKO2_SCALE) + 1500.0;
    float newRdRaw = newPhi * GLICKO2_SCALE;
    newRd = (newRdRaw > GLICKO2_MAX_RD) ? GLICKO2_MAX_RD : newRdRaw;
    newVolatility = newSigma;
}

// Single-opponent wrapper. Same math as a one-game period.
void Glicko2_ComputeUpdate(float rating, float rd, float volatility, float oppRating, float oppRd, float score,
    float &newRating, float &newRd, float &newVolatility)
{
    float oppRatings[1], oppRds[1], scores[1];
    oppRatings[0] = oppRating;
    oppRds[0] = oppRd;
    scores[0] = score;
    Glicko2_ComputePeriodUpdate(rating, rd, volatility, 1, oppRatings, oppRds, scores, newRating, newRd, newVolatility);
}

// Calculates Glicko-2 ratings for 1v1 duels and updates player statistics in database
void Engine_Glicko2_OnMatchResult(int winner, int loser)
{
    if (IsFakeClient(winner) || IsFakeClient(loser) || g_bNoStats || g_bSuppressEloUpdates)
        return;

    if (!IsPlayerEligibleForElo(winner) || !IsPlayerEligibleForElo(loser))
        return;

    if (!g_bGlickoPeriodSchemaReady)
    {
        Engine_Glicko2_OnMatchResultLegacy(winner, loser);
        return;
    }

    int now = GetTime();

    Glicko2_EnsureSeeded(winner);
    Glicko2_EnsureSeeded(loser);

    int winnerSealed = g_iPlayerRating[winner];
    int loserSealed = g_iPlayerRating[loser];
    float winnerSealedRd = g_fPlayerRD[winner];
    float loserSealedRd = g_fPlayerRD[loser];
    float winnerSealedVol = g_fPlayerVolatility[winner];
    float loserSealedVol = g_fPlayerVolatility[loser];

    g_iPlayerLastPlayed[winner] = now;
    g_iPlayerLastPlayed[loser] = now;
    Rating_RecordMatchOutcome(winner, 0, loser, 0);

    int arena_index = g_iPlayerArena[winner];
    int winner_team_slot = (g_iPlayerSlot[winner] > 2) ? (g_iPlayerSlot[winner] - 2) : g_iPlayerSlot[winner];
    int loser_team_slot = (g_iPlayerSlot[loser] > 2) ? (g_iPlayerSlot[loser] - 2) : g_iPlayerSlot[loser];

    char winnerClass[64], loserClass[64];
    GetPlayerClassString(winner, arena_index, winnerClass, sizeof(winnerClass));
    GetPlayerClassString(loser, arena_index, loserClass, sizeof(loserClass));

    int periodId = GlickoPeriod_GetId();
    int startTime = g_iArenaDuelStartTime[arena_index];

    char txnQueries[MATCH_TXN_MAX_QUERIES][MATCH_TXN_QUERY_LEN];

    GetInsertDuelQuery(txnQueries[0], MATCH_TXN_QUERY_LEN, g_sPlayerSteamID[winner], g_sPlayerSteamID[loser], g_iArenaScore[arena_index][winner_team_slot], g_iArenaScore[arena_index][loser_team_slot], g_iArenaFraglimit[arena_index], now, startTime, g_sMapName, g_sArenaName[arena_index], winnerClass, loserClass, winnerSealed, winnerSealed, loserSealed, loserSealed, periodId, winnerSealedRd, winnerSealedVol, loserSealedRd, loserSealedVol);

    GetUpdateWinsOnlyQuery(txnQueries[1], MATCH_TXN_QUERY_LEN, now, g_sPlayerSteamID[winner]);
    GetUpdateLossesOnlyQuery(txnQueries[2], MATCH_TXN_QUERY_LEN, now, g_sPlayerSteamID[loser]);

    ExecuteMatchResultQueries(txnQueries, 3);

    GlickoPeriod_RefreshEstimate(winner);
    GlickoPeriod_RefreshEstimate(loser);
}

void Engine_Glicko2_OnMatchResultLegacy(int winner, int loser)
{
    int now = GetTime();

    Glicko2_EnsureSeeded(winner);
    Glicko2_EnsureSeeded(loser);
    Glicko2_ApplyInactivityDecay(winner, now);
    Glicko2_ApplyInactivityDecay(loser, now);

    int winner_previous_elo = g_iPlayerRating[winner];
    int loser_previous_elo = g_iPlayerRating[loser];
    float winner_previous_rd = g_fPlayerRD[winner];
    float loser_previous_rd = g_fPlayerRD[loser];

    float newWinnerRating, newWinnerRd, newWinnerVolatility;
    float newLoserRating, newLoserRd, newLoserVolatility;

    Glicko2_ComputeUpdate(float(winner_previous_elo), winner_previous_rd, g_fPlayerVolatility[winner],
        float(loser_previous_elo), loser_previous_rd, 1.0, newWinnerRating, newWinnerRd, newWinnerVolatility);
    Glicko2_ComputeUpdate(float(loser_previous_elo), loser_previous_rd, g_fPlayerVolatility[loser],
        float(winner_previous_elo), winner_previous_rd, 0.0, newLoserRating, newLoserRd, newLoserVolatility);

    g_iPlayerRating[winner] = RoundFloat(newWinnerRating);
    g_fPlayerRD[winner] = newWinnerRd;
    g_fPlayerVolatility[winner] = newWinnerVolatility;
    g_iPlayerLastPlayed[winner] = now;

    g_iPlayerRating[loser] = RoundFloat(newLoserRating);
    g_fPlayerRD[loser] = newLoserRd;
    g_fPlayerVolatility[loser] = newLoserVolatility;
    g_iPlayerLastPlayed[loser] = now;
    Rating_RecordMatchOutcome(winner, 0, loser, 0);

    int arena_index = g_iPlayerArena[winner];
    CallForward_OnPlayerELOChange(winner, winner_previous_elo, g_iPlayerRating[winner], arena_index);
    CallForward_OnPlayerELOChange(loser, loser_previous_elo, g_iPlayerRating[loser], arena_index);
    CallForward_OnPlayerRatingChange(winner, winner_previous_elo, g_iPlayerRating[winner], winner_previous_rd, g_fPlayerRD[winner], arena_index);
    CallForward_OnPlayerRatingChange(loser, loser_previous_elo, g_iPlayerRating[loser], loser_previous_rd, g_fPlayerRD[loser], arena_index);

    int winnerscore = g_iPlayerRating[winner] - winner_previous_elo;
    int loserscore = loser_previous_elo - g_iPlayerRating[loser];

    if (IsValidClient(winner) && !g_bNoDisplayRating && g_bShowElo[winner])
        MC_PrintToChat(winner, "%t", "GainedRatingNow", (winnerscore >= 0) ? winnerscore : -winnerscore, g_iPlayerRating[winner]);

    if (IsValidClient(loser) && !g_bNoDisplayRating && g_bShowElo[loser])
        MC_PrintToChat(loser, "%t", "LostRatingNow", (loserscore >= 0) ? loserscore : -loserscore, g_iPlayerRating[loser]);

    int winner_team_slot = (g_iPlayerSlot[winner] > 2) ? (g_iPlayerSlot[winner] - 2) : g_iPlayerSlot[winner];
    int loser_team_slot = (g_iPlayerSlot[loser] > 2) ? (g_iPlayerSlot[loser] - 2) : g_iPlayerSlot[loser];

    char winnerClass[64], loserClass[64];
    GetPlayerClassString(winner, arena_index, winnerClass, sizeof(winnerClass));
    GetPlayerClassString(loser, arena_index, loserClass, sizeof(loserClass));

    int startTime = g_iArenaDuelStartTime[arena_index];

    char txnQueries[MATCH_TXN_MAX_QUERIES][MATCH_TXN_QUERY_LEN];

    GetInsertDuelQuery(txnQueries[0], MATCH_TXN_QUERY_LEN, g_sPlayerSteamID[winner], g_sPlayerSteamID[loser], g_iArenaScore[arena_index][winner_team_slot], g_iArenaScore[arena_index][loser_team_slot], g_iArenaFraglimit[arena_index], now, startTime, g_sMapName, g_sArenaName[arena_index], winnerClass, loserClass, winner_previous_elo, g_iPlayerRating[winner], loser_previous_elo, g_iPlayerRating[loser]);

    GetUpdateWinnerGlickoStatsQuery(txnQueries[1], MATCH_TXN_QUERY_LEN, g_iPlayerRating[winner] - winner_previous_elo, g_fPlayerRD[winner], g_fPlayerVolatility[winner], now, g_sPlayerSteamID[winner]);
    GetUpdateLoserGlickoStatsQuery(txnQueries[2], MATCH_TXN_QUERY_LEN, g_iPlayerRating[loser] - loser_previous_elo, g_fPlayerRD[loser], g_fPlayerVolatility[loser], now, g_sPlayerSteamID[loser]);

    ExecuteMatchResultQueries(txnQueries, 3);
}

// 2v2 does not move rating, RD, or volatility. Wins/losses and the 2v2 duel log still persist.
void Engine_Glicko2_OnMatchResult2v2(int winner, int winner2, int loser, int loser2)
{
    if (IsFakeClient(winner) || IsFakeClient(loser) || g_bNoStats || g_bSuppressEloUpdates || IsFakeClient(loser2) || IsFakeClient(winner2))
        return;

    if (!IsPlayerEligibleForElo(winner) || !IsPlayerEligibleForElo(winner2) ||
        !IsPlayerEligibleForElo(loser) || !IsPlayerEligibleForElo(loser2))
        return;

    int now = GetTime();
    int winner_previous_elo = g_iPlayerRating[winner];
    int winner2_previous_elo = g_iPlayerRating[winner2];
    int loser_previous_elo = g_iPlayerRating[loser];
    int loser2_previous_elo = g_iPlayerRating[loser2];

    g_iPlayerLastPlayed[winner] = now;
    g_iPlayerLastPlayed[winner2] = now;
    g_iPlayerLastPlayed[loser] = now;
    g_iPlayerLastPlayed[loser2] = now;
    Rating_RecordMatchOutcome(winner, winner2, loser, loser2);

    int arena_index = g_iPlayerArena[winner];
    int winner_team_slot = (g_iPlayerSlot[winner] > 2) ? (g_iPlayerSlot[winner] - 2) : g_iPlayerSlot[winner];
    int loser_team_slot = (g_iPlayerSlot[loser] > 2) ? (g_iPlayerSlot[loser] - 2) : g_iPlayerSlot[loser];

    char winnerClass[64], winner2Class[64], loserClass[64], loser2Class[64];
    GetPlayerClassString(winner, arena_index, winnerClass, sizeof(winnerClass));
    GetPlayerClassString(winner2, arena_index, winner2Class, sizeof(winner2Class));
    GetPlayerClassString(loser, arena_index, loserClass, sizeof(loserClass));
    GetPlayerClassString(loser2, arena_index, loser2Class, sizeof(loser2Class));

    int startTime = g_iArenaDuelStartTime[arena_index];

    char txnQueries[MATCH_TXN_MAX_QUERIES][MATCH_TXN_QUERY_LEN];

    GetInsert2v2DuelQuery(txnQueries[0], MATCH_TXN_QUERY_LEN, g_sPlayerSteamID[winner], g_sPlayerSteamID[winner2], g_sPlayerSteamID[loser], g_sPlayerSteamID[loser2], g_iArenaScore[arena_index][winner_team_slot], g_iArenaScore[arena_index][loser_team_slot], g_iArenaFraglimit[arena_index], now, startTime, g_sMapName, g_sArenaName[arena_index], winnerClass, winner2Class, loserClass, loser2Class, winner_previous_elo, winner_previous_elo, winner2_previous_elo, winner2_previous_elo, loser_previous_elo, loser_previous_elo, loser2_previous_elo, loser2_previous_elo);

    GetUpdateWinsOnlyQuery(txnQueries[1], MATCH_TXN_QUERY_LEN, now, g_sPlayerSteamID[winner]);
    GetUpdateWinsOnlyQuery(txnQueries[2], MATCH_TXN_QUERY_LEN, now, g_sPlayerSteamID[winner2]);
    GetUpdateLossesOnlyQuery(txnQueries[3], MATCH_TXN_QUERY_LEN, now, g_sPlayerSteamID[loser]);
    GetUpdateLossesOnlyQuery(txnQueries[4], MATCH_TXN_QUERY_LEN, now, g_sPlayerSteamID[loser2]);

    ExecuteMatchResultQueries(txnQueries, 5);
}
