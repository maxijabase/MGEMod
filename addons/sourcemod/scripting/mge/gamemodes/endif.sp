Action BoostVectors(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    float vecClient[3];
    float vecBoost[3];

    GetEntPropVector(client, Prop_Data, "m_vecVelocity", vecClient);

    vecBoost[0] = vecClient[0] * g_fRocketForceX;
    vecBoost[1] = vecClient[1] * g_fRocketForceY;
    if (vecClient[2] > 0)
    {
        vecBoost[2] = vecClient[2] * g_fRocketForceZ;
    } else {
        vecBoost[2] = vecClient[2];
    }

    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vecBoost);

    return Plugin_Continue;
}