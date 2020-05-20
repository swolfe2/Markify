if(and(not(IsNull([qrydbo_BidApp_Rates].[AWARD_PCT])),and([SHPD_DTT]>=[EffectiveDate],[SHPD_DTT]<[ExpirationDate])))

Exists: Min(IIf(IsNull([qrydbo_BidApp_Rates].[Lane]),"Not on App Rates",IIf([actual load detail].[SHPD_DTT]<DMin("EffectiveDate","qrydbo_BidApp_Rates"),"Before Date","After Date")))