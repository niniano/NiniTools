local ADDON_NAME, NT = ...
if not NT then return end

-- 2.5.5: Nini_S2 EXBoss M+ profile (opt-in).
-- Nini's EXBoss M+ settings (based on the Naowh EXBoss profile) with every Naowh
-- SharedMedia voice swapped to EXBoss's own voice-pack labels, so it plays the
-- voice pack the player selected (NiniTools offers English).  No Naowh sound or
-- font file is shipped or referenced.  Import goes through EXBoss's public
-- EXBossWagoAPI:ImportProfile, the same path NaowhUI's installer uses.
-- The player's previous M+ selections are saved and restored by /nini exboss off.

local M = {}
NT.ExbossS2 = M

local PROFILE_NAME = "Nini_S2"
local PROFILE_REV = 1
local CATEGORY = "mplus"
local SLOTS = { "mplus_tank", "mplus_dps", "mplus_heal" }
local SLOT_KO = { mplus_tank = "탱커", mplus_dps = "딜러", mplus_heal = "힐러" }
local ENGLISH_PACK = "英文(ENG)"
local ENGLISH_PACK_ADDON = "EXBOSS-ENG"
local CHINESE_DEFAULT_PACK = "EXWIND(默认)"
local LATER_SECONDS = 20 * 60 * 60

local DATA = "EXBXC:D33A0Xr1DEs12zswCsalmYooKGGLqmJdq9(HzY4rTKSXB8dfjbmjBYXQ6UlPQh1QRov3TFKSmhBfJXeZtfBYSRbci8mKmGbIXjbSb790N8n(sD8HZM(B7eVU1JDMz3z8atMm51EVv1v1v11T7B1x32Py5CaKkv3h)U)F))()ElQnLQyAT8Af7DKPlKRCrXtQwSy2jZpTw(sffN1(z7mtHIM5ZMp7olYoNZt01uZz9rQ)lLuZpL1hzKcQznlUwXBnBgRpsk1YL0nm3K9Vy9Fy2TdA9ygg5kMAxQ5kRv8AtMxDAnt4J35OSjlxuZSxRviEHmLZpPMr(DuOuwJ8fp4f2Lr2mftRAUtvtT8Q9oNAzt1rnkNpdy(MTK20fp0NQWDNwTKAoJj3qWxEdaun9E3zQYtmXgy4yO5y53GAMmAzeNnD5ILmMERJUTeZv0OSzATX2BbTKfutp1i5utPLl18p(ln)tFIcSTONlKtDVAM7mJwJoNwXPZ3K1QsyT6ulEU35IN(0w3OvVWgKkNwg9c8rR3y54e4e2GP20g7sltVwFA9Oopyf5uKyCMhDu7eOP55iODkYYk1X9TBTQlKm7Kpq2jlUH(6pNQ50Wokze7ihiRwOqUSGwaj9BjFAtn1ID4eswHvq2pHOYfFNNFX5E5fM5TQ9KpgKC0j9gVclNmbllCCCke1oEzooVLZcRXB9C0cA5Y1hGRxZSV9AuUt6tEahblbZffffgsyjyLy5L81UilCs35dgOD0SIDE7Cz3AWMy9FSt5nyz5L59OvwF(iJvWuwGaSYkkjRWFznN5yyK48g6vv4g94VgrnBM(EavOo(jJAVXkdL2qpHIYcblVOmltaLM1o2zx8HoBNIkAAgUaY8Zw7HpyTJ)W9VJH6WUIvrur0hZ7fuZvc8UgtSZjuZpzXETwzVw9mFJEl4FoCVXli41BRYITHbG23qaIGKAKgaW1srrXgkKT6RJARcpdsHjCTtwGP(6VO9yEJS5koDh1dscUMT68zTKahstEyAhdTIepzJjGnH2)QmlGnBJrTXC0a1pemHzbtxwKkYX1oEbrfm6nWnLfz5iAOLKLerp0Rc47wHCAW2wuRKUPAUSfRlGDOvxq2Daq9wim6li73CBN1AfgGIi0tYoSJePfyjFAa4PUmaHenxZwJ6SEaUiQCz1dkCm(8EHGEGdymNP7qkOPDn01ChTHoPJaZizGdg(1e3ztezW)eWrdqGbpZc)nNHOztDwv)ZgPoO9apiOzLiLfdOMNjGdHDCRPPjT1aGlZiC5WAbyVzCJqRZhFGJtkYmK2AWSNtPfAG7i6NeROGaPZcifGNCfmScIbcf6E7OwxxhBRcV7sMLtT3DMl7eA7Samhb1TdSQg(r20l43rsozEfx9o1LXM)r(UGO3DxJfAvNeAfsaat0UD1(McMcssnR6lQTvItujW03skK9zSdpnBdT)jGnnsRCsSs8bzmxJZqpE0hAgb3iWia5ck(1OWfT2b95dm1BAqJeGvy98fsecyiybSlNBFZVVzJ(0gytGUPrpYtDgAHwPliY9HdFkY(isRcqYohkYENmhKyPfiI2jYjkE5XUlbCwIuPnfwrEg0RDdeTUWB9VLjRIoceb7CE4Qn3pV4354lCSZo3uGaXlUttTILCd68p2TtB8N83FSIkkn5RDExGDxiAAimXaIIlOs0F8(x8f2NBFCNy7ditLSutKLO0mAwLMfMJuZuCDMPoExBhGxGdZkm(TNfT2ijhK35b7KLhAGtP(gXi0erq8t8ESiGLgqCMrSPs08kSD6O1S33sDc8ePdew76Bp)Q9QPihAg2imCIcaFkqS0SYs6A7mvUS5ZaA6o3LAonhbO)hnCdi0BeIqdSMZ7ptid1jn1oiWwQBOdMfcmC8n70Bh0CErjb)8BDstL8IKTEw0x8X)P1o73R2Cp3ch77eYVk8DiNmRBUl74MYlt3S6HoP5aNMLiCKLKD3lbIgzbz2lNMlt3QCN0b9IeliwyYGViO1ONaxkJwEOd)5b9KP6utv3D9BUHtan9ciwBe4X5feU(qqqqYN5M(6OglY4Pk)274rMtwMUf(qe5(aO9JMPjUd6w14a6n5eOL8hjBKhsadjVFn0rD4yc4O3arE4CwLAPMWipVbb3ittaG5Ovue5jOHSIa)74iM1sKbDun4AiNapDZ67Jgnk0oPyj4Yqg5oquaLAcSZzzrGpF(dzoYWvee9NerRtISHYuz0BSISiTNFd19626(I46eWfBLa6etT0p8hn)rFXov8hYAY0adj6W1COGfrR5cGqxfiLXMJtHMiXjOLWMaBKBlqpjpPeBoggrfKbPIBu5L4c41q04o4yPdSv7rE44K55qBoCUPlBMb8QMg72ZkRNN1n(BbNhaulr7Nkd3EQ7crRcVEXW53V37gBBaluYkbtjDegiwfb(azIokTHrqrUz1JrPDk8YsnNUMi1ojGwvcwfbmbaVBcPIznrA1KxGxOJxnz4f5ArOW3jwEfqKob3Q5)0OmIIcqjAu22VFWmWSKz2jNuZCe75KF)JWY7QaI9kS(58rBDqMroW6qLlEUND(hD)l8sNP235hek7aTfFCb2TIO0gfbAobu6mWUo2X0BGqxtP7nAntmyEYBqwIuZfPL47W1ea(ce(bwYpdVsGn5osdcpNqlQdfuS)He5K4PdUygbHgfzpYMB6Y(R(Ux8TpEhnWSH2Y2ibxjfPldYiRmJcYeF1M2iWjZ0CcxJecfye6WHcAX2JldO1nL2UGfI6HEIFg3H(mNmn4NnvZnM2EkLyUI6g7oz58jvnhVqVLunNuRu)50mlnciK2HQxZLxQGPM9dR)GXhjTbWiSyQIP11MwBM0gg5YyS78ZwUO2a2ffQoC3p83DJc(5sJAxLOwBScCqhl70AM2d7n087blP0zChZvu4gtBuoFj4aC)gztR5oRgXSCoTI9oxA1ILEaqm4g7EIcxp8xgqxl9uUVvHvcFeyCgrdwRS2GUWQc8m3x9KM(W8fQ)kU)oCPFvnprhwTKEIkUZuyFZ2FMmfwTV3Z)uE8c3yiOclu2eUKKTQPMHAM669l(zNWruYSuPIoelNkU1EuD0PNaAOW6FpH1V29bu1BuGhcweCxchgWQSDaOba0zmBaWXpV3BbNiRiabClPnY7TME9EVOhYwDZiBS6t6W)fVU5glvNhiiDOqpbFUt38Pd0nAQ5kPxVb3pREH147VcF)g)PLdy5T(FMW6VBCRFHU1fg36)LO1fTQznpeXwlyTrRfh3APew)VxH1FVU1)qVw)Jty9)r36)BLTKVKM50zlweyz26FACR)zDRlnoSn)ljSE)QuFuR)1XT(LjS(3OS(vFwel6w3xZ0MuZF4hz(N(eOOqvP(yw)gDRFR9C63TcRFVEvQRz8QuujQsLa8Zld8VlVIt7x8Cp3cN(CvP(iGN9hPFBecVew)t62qcYzBdPeyaue51CXHElXrc35EgcN7JKutD6IiOjxlgiW2)ogQzuyjHcgws4PhNe0BRB(h9fauJ7WfsFdcr0izNOeke9jWGOklEUJv7H(RV4BEIAN7B3m0Qs9jrZS9jXdoWl5IPlYsgOMzm18t139MTecCDDHX14bWvTN9VP2dD4AV(tx7qNomUUE0466JcUUExC9RidwqftMA5qrTwjgQvQfp9jxA)NlKIHApZRp)ZEo0y6gWJPkZ)g)G5pWt405UO7xtg6y3QXOiq2nIbzZw7XEHfFPdU0d)4Hjw9Igy9IhyGxYfo)mgYWtCqp3fjCUBUjtJ8aN9qqpwngquLQNqCza(JAh)uOjgRbpXOcS9V9(aDrTh5XCH2VNmKX2VXqHqfqNloqTIWCxRanGwbEazj5XCrtgmcZCnlms5ZCcyvZJX9aPo1quRz0Qs9P9y1iejS7Omk103eoue2jhixYZCi0eLpdEIc4LCXY)mzqz2bgOVTmT6KAO0q)zXbO1ecqlC2Jp)J)sOb0nJhqxO2Ho4IN(LxNZHHZZrH3)UjdDMdAhKhkSDl4S(4C(TclcDROb3TIhCvw6yhS2tEO5pYzN)1pLl0(aYqguPwZGkLJ2gS6fcr1apIyfDvPUnxO8ljfk3cb0Nk1E8ZSWmV5cN5CZ)c)KWa6ZHgqFUOaOpNlGw(hNmeLChMPqXZD7445Q9Qp7cpXZh2JNN8BVWt(TrJO1ffeToxeTkcre0h0o3VuG7JDtVrVGJBURd4)(8V2SnuoCRKHjZ(3JwFzZNgbW(JXsOo(ln)((BBgCZT0Z(8lEUNk5ogDu0G8lGhKGxYfyh5lqgWitGkfqV0sVicpsVt0y5oXJLkW1JZ(woDShliXOkgWc6lGOJtOOuL(HNiW(giRz6CAiq0DJv)DiNvbUbqSleEoQ(sahrCX27TEYWgmrpDEYFQS0F1pz(x9hV478kZ)yZfgBmOXgdESbEjpLeeIOKBZyxHPsJmOA(0A48o6Dd5067I0P13fpsSExpLcecKQuRngfdXQiefjh1qDkeSy84uUb8RC(d)qHbJaAWiGhm19MZPJDXfpH4Imv2aLWDt11vPUlpLBBGmCK8lLn9uHIZBo4tl2xrdJ84KzYesMjdszMm4HJvgx0yqgygXwtnc6Icw6ccv03a5zSQUkA78E5LoyzYav4OWHzkFPZ8uooxHfz3tyKDpOr29eLyXVhx8mnzWbvCqrjHpD5yG(uEPuGqYczwobg4cVVjp6lS0jMbnw(tWJfyCvW00V)FmOxCrvjjYqvyMTrGB(yrSARF4ZS0(2hI4GElGJKOH2FgEObEjxangHaA2rlzuOVbulIk)p9JZpNA7)zM)eZn)t)oZ)ghnm)xs0alzuaw)EgGieyMjnkNlJMziyLmPA2sw)R6DO(Uu1E7J2YywhkkqAqpNrjesj7ptgurHVjSCFV(tGi4UQuBgnA2mE0uP2ro(shCwNo2fxNIqCf3ce6ieIJrgTqwKBJxBD7zJWj4T2vtl3IN6uorP6lTCLejduvgvBxAWsJOV(3dQO7(syWM1dgYbOhePdqpiEGDbNuyUoNJvNx(sgJqO11mrD5ijbgqpvDyWrVTsVWWLZHAxI2MTwoR7RdYF)LdBhya9coLqksQHYxYy6uiWY2X5NnI6T4Op1fp9PrdNDef4Sdx4CGBNm4ePDFC8GQQFRto)PotyYYWOXXW4DjnHN6zcjkvPKcHd4ZU6f4tfNlJGGwBocXWjgyTXnZVaV)w4epRNMSBJqgTKRFWTTzeOAuCePFEiI0phjr6NJhsvCUXWCQHtpvAxlzaQZLC6(7B)Rr2uhDaCRbRvLUCaCRXZ6ipP4iIYjnZ9FLqoPjl(8eJP)qRkRk1x2lLHecI563yO(wFFiZJBvQ7hhycLe3lNeGAxeCoxhtEeN3Jqz(iZWDLuXSVWaUpeWyMP1sRRMpBASOjSgm7u2E0xeBm12QrDE3Wi7RIgzFv861Qs9v88eGykumi3uUbb4CIuASPPewnPj3QMAHWvEWI)03aE3dJdzF9Wi7RJgzFD8id8sE6gienH56m3u29OwsdxgQQsDZHHYnJgkrOSxQm)J)s1o0pjOhBJriO6ASDKh5zvQT6IIrjdeN0rR9GgzMeLA7XXIMqBCfSwRAzgPuJcMu9Y9(kiduvP4qGfoSyPRUHV(QzS3NWAvo1a6WdqacSKcBU1o4jx6ihomE6bnE6jk4zvEjTHy6sxsI5YrrDfhf1bRy0bjerPCuJfEhFxlo)DwBiTaRfPwG1IhrwR1tvgHWGSTfnvTx)alC6qfoEvQjqtCMapuCTI60ZEwrpfH1QCQr1ZQLd1wlQJJ(S3q61w45p1ch7SOHww8qd8sEUIsiCiJm1LtJ7jRtIgChJ1iWhI57cxSeqh8XbOUA1saEjxCStsHrSiebpYXQiMCWJah4Q5JQucHtYP9bqcnwMkkyzkxSCrIXsSGM4f227tmo6s2mtTWZDaqqCOXso8yPIt7d678xNmqz9bHTy(byH067MBWrLfFNxzH9)YbHZ7rmrAteSbOG5z3ervPUxxCCCcXH52mmYpvwuNSudSGbX(prEjfwzHx5vU4BUpNkw0ZnacH1CBvTyP(gwxTikFP)g)HazpsqKDacrw8QAdpcHOizsn1Wvervk8zhO7tzo9JgKY8JjdsK5QMDTHFIzcdQYObv5iaQAp8PHLAKDh7cQhJuqr2ot3vz3CYT7B(dx6y)TEo8C87Kmafh2pNLt4CVR5S2LtX5wLs0ZPZ)esXr8YrTls6XCXjznOk0M9GLOKomysJgmPXdMk1E7Jw71EBNua5cRdtgQIjE2K3J6q4PAjSKUTEeNcG8oWcNnggoBenC2yuGZ30fo3gHWzKVuEJ0Okq)VfjqHCLXZaxe9NjGLtiGiLpJGycAToz3ycSp0zUi6HjfqK4aqfNlDYLoXrqw6Q)LOH2FjEcLBI1C65ggoj(CuCTiqhUB6KQutegtt1nYsWGeJJVv3siQ7OpGqCG4m)N0OyX(swEIjWLPZN8kKH0tr4zBXUAicrtWfut3SAiACIwgK4Q5shDsNBB9DhoPZvPYEzKWzDxy8tjffK5VF4dlHZXCanu2FuGYx0fk)isHsxtqNCRL(f0jmu5yboAeXF)KHIudL3uf5gBodwKekysYRnW5aEVS(Gvg4r6HmeHENmWTlGidnE9OPlRhpECCP1oJMnk7jc375UgGQ4C5ZawJR9QVbAO9q4HwvQ)lEUysOOtQ(Nov5IO0lFqC2w6IhwaFLSXyeEg2cBSVk1(WbHqw5BFIlAna8sCX7rCa)KXz1vdPSsTN4vQDKJhm9)7GuafdYGHBjPcJO9fFUg7mlH8yKsK6QP6RHDM3JyyqsuyvPk3ntbBvQD5IJ3))pbhhpOFX624iLZ1DQny09dgkC6VUID73P3kLxdsyvoxL6RHGq81Wsi6QvKzfNYW1PyqDr0JqkGydbOrgTKA6PWzrjufBNY5MAanSE0ialV7TlFxJnVbzWks8yxHZS)2iBQ312CCYDKSk1d6fOcMtDARo9FTafG4Ft5C7n1zyHCl9wFGNJJKEaAh0uf5EI)eTJQyFaAVHWiH87NIcRQEs88)TpWZs)fjeDvP2ccOTfSmCD1IkRk1)jxC8ZighXRAj74eJJ41b16aeJJRZvh8F48kgmGU4idXPY7Mqqp687GusJ3cmwUq4lrgcsnAbtnvNQGDCBlIUO4PWYv9vdtnAXfdYJJhkvC08dmW77oq72q5kjkur1mD5Wiq0HXEfA8OHCBXz(GgvF3WOsVv27paXCyXRDY)IeJJ7gboi6E2JCJKZ5CT)TPSMAEwuiepPgZOKgYR0)JIt6pePXcjLXkceMlv7yNDXh6SRBH9)Y35sh7N6zVVeHhk7o3Z4QudhMc1fo5)JDvdbDFF7ViHBu3C2Hw1367BGbqO967HvwbrsWUmooCobC5Cxs7HmIpfMOUGmsJfrD1sFb8sEPAHW7n0zgtlNwbdtu38u)xXIMUCbjoZBT037hCX3(5xAF73fxNIWJRyKKA0VYk18fjBQhRsW6Ip8PM)enow5VpXIlhm(SteLiKNAKwDUrFgm0MKBESnTJWuhYpDIxW57mY6M)PFPAh)uEuN3ImCL8EZMbfS((yL)7nK3LWVfoTY7YNhpWQ)T0z(VZXx4yN1ZJgc3cmu7CKjwmrGoT2DE)nDrrzYab8(DpmPb3D(EvQpFyymeAyeP7nVH8cGHWujJOKehrTqjdZ(Sp7)4sT0vQ49xoHWjwOK2x5hTCc)wwaJkURePmUpDkTdfEB29xMuqSheedcQd5uoFOqqtqEr8qXDFwT7fVnF5YjLsOyXAoK)RSSyEPu6eKcJUu8(Pw8n)HT02YFnEOCbN238h6HdqO3aXenaEzwQiPW4PqadcuaC5LizVsfZSKPAr9bg82NPOwPszZpzXdD9f(m6apuGFYmlKtTKg87Gz)Pm2L2OAGFktXEKl8zMstRG7NZ0(NOKM5iAQz2B9x4glSY8(Bm8Rt5Hw7LM0untwT8EFmm7zYLnZFr5ILYoXEV)uBBldo4whQN9s1ZEOQuuxnJXUha(fxT)LLY530twm73u7MbWY05b)5lZ0OCPCzZRzUJ7BSTULTpupMlZFthjqhLKYDWU3KBDOnn2mMgLS)eutnRA5sgpq2mL01NzA19y)tu1hKVYnDnN3DEB)L8K6cU)6w1Ypj4fNBIS7rlJDJoWh3)aUzQKtyKVuIEuxwpPwwHvdxt3Qr(jDx2A85AnWI1OauYD(ap6q3uLugWV8T1bY5D(THvZKbqWO8)h7FzMflOMg84LnYUHZP(NZ5Vc72Lnd8RqlShhVExaPmLn1kSYr)gLvn16BtLZLRVhqpBjn7pyTdu)RC74ZPzpzhW0OW4ZKg8F3Q2eLU3nEQV5V4p7AUMRXQ29pl81hD3zlOn(SAaV27pxbD1Lz)0Kas0K62d9qG)Y4Zve(A2VWWlN(UefC(G8ApFgVWkHjtEVj9JOWpBZWgklycNjJzuGQqp(Ed3VpR9SNVW1mh8nsAuQKX037g)hl8I)3bZ2WDxYHxg9DXolOv5ZSnJmAJayq2(GaEr)RSBMkCdhXUHP01YoPEP(9)2JqDYmAfvblUaAygDtt4fkBrn9cxVhLDhtmbqK7Rqb4OVW0g5Zc8nZ7tlBlKV8(73GxVSztJDxsFuaV1iMWzrHEci7U9HhyldQxO3Yf1GDhuAz00MzluAi4Nh5XdnD(Z)e(6BB2rG(HsQSBDhpqyo46I7aXScA5Ynu(sMz1kEOhRqpcYYBGvIMJwCdmG)JcdZHwhqz5fS)MmBV(axMtM3iVM1FN(C7c(bdM15B87VW2R1FVEJpmVqEuGI(cRcEH8oqZFSJbQzlCtWpCXdBAmPPwXIn)T1DCGsvOQpWYCf7bIP(3K5EpPZVA)9igO9F26)6OBlHZlYg8fzD(WfpB9Fb8Aa97N3PrEJ1FpyTUPzJhrZ)3wy43jupfaFkKZ)64(8qPdp6jqaPXIOBhmxJhTjGsvGAqhDoqRa)gG(f4cxWV3Wol5mol5)UvCHgVH9xEy4(quX9lsmCSTDlzzJ7A0asHf2aROKaVa8lyVSclV9xQ7E4uu2aJIKaNGnLNtu055S8GNZjXlXbFFrrjhoIQuxQk1)cGhOk173G2xL6dgz4YG1QQuaNVwe87)sFuXQu)BwBSk1Vcg768h5moNPLQu)7Go7xB1BvQFd4h(TqAtvQFNoGGuL63pE1exJE1euvt8XRMib43awbtSCeRvvtaayI)i4As1eFu71HQj(yWM5h9R0fnYsq2CbA22dMQuFTwIeWe(xzFhOfP5pOJiz(dhF)upN5ppJepKAWlZiGG6XqZjY4)5Y08sqQQeaW2pFL2pxwrwwCdCsC0msoVUGm)gy5feyGeBozor52V(mZ2unNQVTKpnMvPBnQRsxlzRsxBtuzbA4QKiaDSsSIc8ThfZbLPtbCXqZedoU(wGJXBghxhz4iOSQdvsHMMJhsLezWGd7TeUnZFR7lQt)BISP)n12PVcwHT16m9hVvl)RiQZ)1s28FTnRQeOLGtGJLfinWiOiIr1xvk2gaqhX6)72(5VU38NLS5plY1FwABHCfjwxHCGfabwAjiSuuuy4ApSopuixltFRR)DRU37aJesprLePqgevAH1mO)kma1Isye1bE6wkTEF7WmfgETpFubYTtgqUDeaHxqbQ5ILtrwqS9aj5yAflHHwieviWtge4BgcaJhc8Y2qqIHtwaN4YAXaGRYY7oMnePLeHcga7h8bDbcOoa8CjjrU6p3(9fOPTnUYXlJHMf3aSRDsGkaGqeq)wuN)Xef0R0N3qSIkafC4M)snw)rPFotu1plr20xcTZOWPVeTcloDxjZPccnfeT50KzMpKp1RJiyaAwtY9IqvxYcc2onkkJbhXnXG6grKzKHovlWYtJro4sWlh31zFvlKsn9u4mjUXOIMVfzO5B1wTyIc04ihpdga8Srfapdza4zAMCidihmcWio5ObHOG1T3nHrT0MJOab1trgaEQw73fqQGdd70ToWaTxT0AIMAjy)qW03E4djplaczugU(ROW7eCyDRfIW)hqAHMHZV1rbwog4RZsZIjMr7OCAl56QBuwHJDMZ1pzOEngzrWFgOuGvgRGKcgGD1154g2xKDSVGD(tO5r9RKMhL5LvGrXZjJHVkbQjVU7Kpr0M7jizMNWzZzc4hmpGHcQawGMrrb36(MWOaUv6VcX3SjsM(2JFZwqas48kos0mcycqSqpWid7B4YMfYPv)lRDB5KATKqiwjIKeoFttfezqJdQUIvruIrbDg0eWg9IE7d2FVrfI6Kar7HpKtm(IQNdJ4YL(YLZMgM7UsAMMLluImr)RSEgRicf9zeWtl2ognV7iQsqBNS5)2BDMVK5z4u8L1vfbggfOJbCmbIJ0ommaPJHhxwxRMO3yLf0v6tMcyOrwgRcpL4vwKCYgUmlppuHhqicBI(IxbchwJTCG85ZXBBkcamCcsjwpgGf5Gz6oalqkyv4bKOiszAjR1vzkJtSLG5Vmm4yoE85Oi2fngKciccNbMeCjrUGodmEZa4KWntPVb1svEIjqXlP7IKuo35Crm0SeBHi0aAw7YvHKigFIhX(S(0Ed9ysZQUhe2kzqyRiHaJTmnVOIWh2s3Ip)6HXxgH8eZJrP0vUeDpo6eDBRuIvuWwKqrcJ)XJmqzZIT3J4ul(ApuTzNnIUmMy4ofhoCsdJAph4b0aOWaGEGnarCBAs6OsisreaGJFyojjEz7Qvrqr(dzkxd5qiTVDOZLWae1XUXcUoe2sCD11HWE8L5bOzB8zMpXxSTrVh1upmBTZ9YoF9DbWqVJHbCwG02NGtQTOJQQ2yIFHR0x5FWPWkiHJpI0maDLjmW6UVkklbdmINLbxmTNV(H810iFj1CyejWKv1gKIvtgwwnQSAdeXTT6jklGtKGIRBfKehzaGdfVKKOImGxIrIflV0QJveGv6lipojwjoSg7IzPPoGxha6Gm2qH0BlaAzcQcn)1jB(RJA9xswrcU(tJFxcJzoB4VutyvuyLWWavX5tO5MnnkNpt8YdC)B4jhnnWAD7HYjRx1m9NjtrmUXAFtPhnReZ1OxjcvjMOfkOSn2XPGv(iEjGVsFBKgS2uXxTFXRTBQH3421MkiSiSAyJxElfSaMe5eXTXTXTWjQNAaEzyK1SWnGgtK1jARt3jIMp3jiXvBW)h0GwmXfLyX6C0n1EBBxDR01MkEEjbgSjqoMTLFU1CHGDPSjInNmXVAwao)zPzyCYtmolAXqDp(l2agErC5uAedJsfBjte8ywKQ2R(FZ(01gTeS(nichGMHkNsSI0o5uc)w3f7ienkexGVrGyoDZjJDUaOTJff8x5eAFEWtT5CQz3LwBtbERpyendUe7Qtb342uNDHYfdEgbzNcMeRbUzAFQVZhnPCy)0HtFhAZmTqlLZPFrqeBme3sBvZMAXx7hn)Jf1TGa0zebIBPfXryhhNcdpojKe91wqC12wxivT4M)Xm)SBU(Cu4WWfzhi36g2iBrJ83rCtzvWsnIgNl3XSkhiKWaRacTTmIcSyTNhVyYcCa7K5Lz58xbi1JrLrIfJv(4ws0cwqbCs4nVhZ2zIGzXKLtb38pMXx1JBzEjW5uMA0kUcmnmncCGxeBnefZ4SCZ(bJcBNFYCrwIHyozU6EZ)U0jZTPdpKewoRyNJVn2SlGkxfCNA24ghup(oonqraA8XagZkdTqz4hJmWC2xa99T1StGRCBXC(R9Kfs8OebeqZqqjSdZWEF5X7Iy8QevCJtsIdw)P0aX5pCn)7PPRXdbgSbkfZug5Ec(PTJcxMb3zuobzzJs)kv2OcwIwyRFJ4PMO6f9hWLdCHif7YNPVcW2wdKGG)cI1xffGrZuf7QzCDjZPPLbxSF)HWtqFxKl0YbQMCrw7CPdcQcxmHXnANFxCTbgUnADu9SA5Y0367deOE73wGRUB5D49zfNDK4w0s(4LSVivWzhpX)54OlHcmI2BRbJSat7tA7i2c6OY5PUhp0dgnBjvt8SebbqZqabNQLfinWrJXT8uo3why0v9vJiDiX3VtbX42G47JoXToxIu8GWJWPtkEfBHBXdrlAx8ks4eKjE7XUI5qIDKf8UrwOGD)jJzoKuxreNcCBLuyeXVbXXUTMpWnRLi)hYaq9qI4u4eGrwa8Sc38pEjbh6YAbNiCCZwCtYW8ss0(pw(nUSZ(WMn6GxrDnU4bdCYPKvaiR9a7sdMfEBw20o10cuMY5UnU9AHBG0UYo)18UVYkxNa2WjfGKfpUS(e70n7V4DG3xeS44aPoA79spYhNNJs28)OOST7DxiklfM)dE1IjHnJ6Xln2n50LanwnduhgdaE0OcGdtgaoCyv2GWN4CowU0YyT5eZuz3CjpJ7YPl2TztnxrNmyfbUUyibWB3(e5XMkKBbdbiYxKPDvlgSc2LeSc(ZLEC687mtA1sAtAyUxReNSG6EZzOMzS9wq78A7jLrXI7mv58zYPz9XT(eMWBy7Sg5VU)F"

local function db()
  local root = NT:GetDB()
  root.exbossS2 = type(root.exbossS2) == "table" and root.exbossS2 or {}
  local d = root.exbossS2
  d.prev = type(d.prev) == "table" and d.prev or {}
  return d
end

local function now() return type(time) == "function" and time() or 0 end
local function inCombat() return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false end
local function boss() return _G.ExBoss and _G.ExBoss.BossConfig or nil end
local function call(obj, name, ...)
  local fn = obj and obj[name]
  if type(fn) ~= "function" then return false, "missing " .. tostring(name) end
  return pcall(fn, obj, ...)
end

local function addonState(name)
  if NT.Adapters and type(NT.Adapters.GetAddonState) == "function" then
    return NT.Adapters:GetAddonState(name)
  end
  return { installed = NT:IsAddonLoaded(name), loaded = NT:IsAddonLoaded(name) }
end

function M:IsReady()
  local b = boss()
  return type(b) == "table" and type(b.GetBaseSelectedAuthor) == "function"
    and type(b.SetSelectedAuthor) == "function" and type(b.GetAuthorConfigurationItems) == "function"
    and type(_G.EXBossWagoAPI) == "table" and type(_G.EXBossWagoAPI.ImportProfile) == "function"
end

---------------------------------------------------------------------------
-- EXBoss voice pack
---------------------------------------------------------------------------
local function voiceGlobal()
  local sv = _G.EXBOSS12S2
  local v = type(sv) == "table" and type(sv.voice) == "table" and sv.voice.global or nil
  return type(v) == "table" and v or nil
end

function M:GetVoicePack()
  local g = voiceGlobal()
  return g and g.selectedVoicePack or nil
end

function M:VoicePackLabel(pack)
  pack = pack or self:GetVoicePack()
  if pack == ENGLISH_PACK then return "영어" end
  if pack == CHINESE_DEFAULT_PACK then return "중국어(EXWIND 기본)" end
  if pack == nil or pack == "" then return "확인 불가" end
  return tostring(pack)
end

function M:IsEnglishPackInstalled()
  local s = addonState(ENGLISH_PACK_ADDON)
  return s and s.installed and true or false
end

-- Korean clients start on EXBoss's Chinese pack (EXBoss only auto-picks English on enUS/enGB).
function M:IsChineseDefaultPack()
  return self:GetVoicePack() == CHINESE_DEFAULT_PACK
end

function M:SetVoicePack(pack)
  local g = voiceGlobal()
  if not g then return false, "EXBoss 음성 설정을 찾지 못했습니다." end
  if pack == ENGLISH_PACK and not self:IsEnglishPackInstalled() then
    return false, "EXBoss 영어 음성팩(EXBOSS-ENG)이 설치돼 있지 않습니다."
  end
  if g.selectedVoicePack == pack then return true end
  g.selectedVoicePack = pack
  -- Same follow-up EXBoss's own voice-pack page performs after a change.
  local eng = _G.ExBoss and _G.ExBoss.Voice and _G.ExBoss.Voice.Engine
  if eng and type(eng.InvalidateLabelCache) == "function" then pcall(eng.InvalidateLabelCache, eng) end
  if eng and type(eng.ApplyEventOverridesToAPI) == "function" and type(GetInstanceInfo) == "function" then
    local _, t = GetInstanceInfo()
    if (t == "raid" or t == "party") and C_Timer and C_Timer.After then
      C_Timer.After(0, function() pcall(eng.ApplyEventOverridesToAPI, eng) end)
    end
  end
  return true
end

function M:UseEnglishVoice()
  if not voiceGlobal() then NT:Print("EXBoss가 없거나 아직 로드되지 않았습니다."); return false end
  local before = self:GetVoicePack()
  if before == ENGLISH_PACK then NT:Print("EXBoss 음성팩은 이미 영어입니다."); return true end
  local ok, why = self:SetVoicePack(ENGLISH_PACK)
  if not ok then NT:Print(why); return false end
  local d = db()
  if d.prevPack == nil then d.prevPack = before end
  NT:Print("EXBoss 음성팩: " .. self:VoicePackLabel(before) .. " → 영어")
  return true
end

---------------------------------------------------------------------------
-- Profile
---------------------------------------------------------------------------
local function authorRows()
  local ok, rows = call(boss(), "GetAuthorConfigurationItems", CATEGORY)
  return ok and type(rows) == "table" and rows or {}
end

local function authorExists(id)
  if type(id) ~= "string" or id == "" then return false end
  for _, row in ipairs(authorRows()) do if row.id == id then return true end end
  return false
end

local function authorName(id)
  for _, row in ipairs(authorRows()) do if row.id == id then return row.name or id end end
  return id and tostring(id) or "?"
end

local function baseSelected(slot)
  local ok, id = call(boss(), "GetBaseSelectedAuthor", slot)
  return ok and id or nil
end

local function effectiveSelected(slot)
  local ok, id = call(boss(), "GetSelectedAuthor", slot)
  return ok and id or nil
end

function M:GetS2AuthorID()
  local d = db()
  if authorExists(d.authorID) then return d.authorID end
  return nil
end

function M:IsActive()
  local id = self:GetS2AuthorID()
  if not id then return false end
  for _, slot in ipairs(SLOTS) do
    if baseSelected(slot) ~= id then return false end
  end
  return true
end

local function publish()
  call(boss(), "PublishRuntimeSelection")
end

function M:Apply()
  if not self:IsReady() then NT:Print("EXBoss가 없거나 아직 준비되지 않았습니다."); return false end
  if inCombat() then NT:Print("전투 중에는 바꿀 수 없습니다. 전투가 끝난 뒤 다시 해 주세요."); return false end
  local d = db()
  local existing = self:GetS2AuthorID()

  -- Remember the player's own selections once, before the first switch.
  if not self:IsActive() then
    d.prev = {}
    for _, slot in ipairs(SLOTS) do
      local id = baseSelected(slot)
      if id and id ~= existing then d.prev[slot] = id end
    end
    d.prevSavedAt = now()
  end

  local reload = false
  if existing and tonumber(d.rev) == PROFILE_REV then
    for _, slot in ipairs(SLOTS) do
      local ok, res, why = call(boss(), "SetSelectedAuthor", slot, existing)
      if not ok or res == false then NT:Print("선택 실패 · " .. tostring(why or res)); return false end
    end
    publish()
    reload = true
  else
    if existing then
      -- New Nini_S2 revision: keep the old copy (never delete player data), just rename it.
      local oldName = PROFILE_NAME .. " r" .. tostring(d.rev or 0)
      call(boss(), "RenameAuthorConfiguration", CATEGORY, existing, oldName)
    end
    local okCall, ok, result = pcall(_G.EXBossWagoAPI.ImportProfile, _G.EXBossWagoAPI, DATA)
    if not okCall or not ok then
      NT:Print("Nini_S2 가져오기 실패 · " .. tostring(okCall and result or ok))
      return false
    end
    local newID = baseSelected("mplus_dps")
    if not authorExists(newID) then NT:Print("Nini_S2 가져온 뒤 선택을 확인하지 못했습니다."); return false end
    d.authorID, d.rev, d.importedAt = newID, PROFILE_REV, now()
    reload = type(result) ~= "table" or result.reloadRequired ~= false
  end

  if self:GetVoicePack() ~= ENGLISH_PACK then
    local before = self:GetVoicePack()
    local ok, why = self:SetVoicePack(ENGLISH_PACK)
    if ok then
      if d.prevPack == nil then d.prevPack = before end
      d.packChangedByS2 = true
    else
      NT:Print(why)
    end
  end

  d.decided = "use"
  NT:Print("Nini_S2 적용 · 쐐기 탱커/딜러/힐러 · 음성 " .. self:VoicePackLabel())
  local _, rule = self:SpecRuleOverride()
  if rule then NT:Print("참고: EXBoss 전문화 규칙(" .. rule .. ")이 지금 전문화에서 먼저 적용됩니다.") end
  if reload then self:ShowReloadPrompt("Nini_S2를 적용했습니다.") end
  return true
end

function M:Restore()
  if not self:IsReady() then NT:Print("EXBoss가 없거나 아직 준비되지 않았습니다."); return false end
  if inCombat() then NT:Print("전투 중에는 바꿀 수 없습니다. 전투가 끝난 뒤 다시 해 주세요."); return false end
  local d = db()
  local s2 = self:GetS2AuthorID()
  local changed, missing = 0, 0
  for _, slot in ipairs(SLOTS) do
    local prev = d.prev[slot]
    if prev and authorExists(prev) then
      if baseSelected(slot) ~= prev then
        local ok, res = call(boss(), "SetSelectedAuthor", slot, prev)
        if ok and res ~= false then changed = changed + 1 end
      end
    elseif s2 and baseSelected(slot) == s2 then
      missing = missing + 1
    end
  end
  if missing > 0 then
    NT:Print("예전 선택을 찾지 못한 역할이 " .. missing .. "개 있습니다. EXBoss 설정에서 직접 골라 주세요.")
  end
  if d.packChangedByS2 and d.prevPack and self:GetVoicePack() == ENGLISH_PACK then
    if self:SetVoicePack(d.prevPack) then NT:Print("EXBoss 음성팩을 " .. self:VoicePackLabel(d.prevPack) .. "(으)로 되돌렸습니다.") end
  end
  d.packChangedByS2 = nil
  d.prevPack = nil
  d.decided = "never"
  if changed > 0 then
    publish()
    NT:Print("EXBoss 쐐기 설정을 예전 선택으로 되돌렸습니다. Nini_S2는 목록에 남아 있어 다시 쓸 수 있습니다.")
    self:ShowReloadPrompt("예전 EXBoss 설정으로 되돌렸습니다.")
  else
    NT:Print("되돌릴 선택이 없습니다. (지금 Nini_S2를 쓰고 있지 않음)")
  end
  return true
end

function M:SpecRuleOverride()
  for _, slot in ipairs(SLOTS) do
    local eff, base = effectiveSelected(slot), baseSelected(slot)
    if eff and base and eff ~= base then return slot, authorName(eff) end
  end
  return nil
end

function M:Status()
  if not self:IsReady() then
    local s = addonState("EXBoss")
    return { ready = false, text = s.installed and "EXBoss 로드 대기" or "EXBoss 미설치" }
  end
  local names = {}
  for _, slot in ipairs(SLOTS) do names[#names + 1] = SLOT_KO[slot] .. " " .. authorName(baseSelected(slot)) end
  return {
    ready = true,
    active = self:IsActive(),
    profiles = table.concat(names, " · "),
    pack = self:VoicePackLabel(),
    chinese = self:IsChineseDefaultPack(),
    english = self:IsEnglishPackInstalled(),
  }
end

function M:StatusLine()
  local s = self:Status()
  if not s.ready then return "EXBoss 프로필 · " .. s.text end
  return string.format("EXBoss 프로필 · %s · 음성 %s", s.active and "Nini_S2 사용 중" or s.profiles, s.pack)
end

function M:Warnings()
  local out = {}
  if not self:IsReady() then return out end
  if self:IsChineseDefaultPack() then
    out[#out + 1] = "EXBoss 음성이 중국어(EXWIND 기본)입니다 · /nini exboss eng 로 영어 전환"
  end
  return out
end

---------------------------------------------------------------------------
-- Dialog
---------------------------------------------------------------------------
local dialog

function M:ShowReloadPrompt(message)
  local f = self:BuildDialog()
  f.mode = "reload"
  f:Refresh(message)
  f:Show()
end

function M:BuildDialog()
  if dialog then return dialog end
  local UI = NT.UI
  local f = CreateFrame("Frame", "NiniToolsExbossS2Dialog", UIParent, "BackdropTemplate")
  dialog = f
  f:SetSize(470, 300)
  f:SetPoint("CENTER", 0, 120)
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if UI and UI.Backdrop then
    UI:Backdrop(f, { 0.075, 0.098, 0.125 }, { 0.141, 0.176, 0.212 })
  end
  local function font(size, text)
    if UI and UI.Font then return UI:Font(f, size, text) end
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); fs:SetText(text or ""); return fs
  end
  local function button(text, w, fn)
    if UI and UI.Button then return UI:Button(f, text, w, 30, fn) end
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); b:SetSize(w, 26); b:SetText(text); b:SetScript("OnClick", fn)
    b.label = { SetText = function(_, t) b:SetText(t) end }
    return b
  end

  f.title = font(13, "|cffF4B23ANini|r_S2 · EXBoss 쐐기 프로필")
  f.title:SetPoint("TOPLEFT", 18, -16)
  f.body = font(11, "")
  f.body:SetPoint("TOPLEFT", 18, -46); f.body:SetPoint("RIGHT", -18, 0)
  f.body:SetJustifyH("LEFT"); f.body:SetJustifyV("TOP"); f.body:SetSpacing(4)
  f.status = font(9, "")
  f.status:SetPoint("BOTTOMLEFT", 18, 58); f.status:SetPoint("RIGHT", -18, 0)
  f.status:SetJustifyH("LEFT")

  f.b1 = button("쓰기", 120, function() f:OnButton(1) end)
  f.b2 = button("나중에", 120, function() f:OnButton(2) end)
  f.b3 = button("안 씀", 120, function() f:OnButton(3) end)
  f.b1:SetPoint("BOTTOMLEFT", 18, 16)
  f.b2:SetPoint("LEFT", f.b1, "RIGHT", 10, 0)
  f.b3:SetPoint("LEFT", f.b2, "RIGHT", 10, 0)

  function f:Refresh(message)
    local s = M:Status()
    if self.mode == "reload" then
      self.body:SetText((message or "") .. "\n\nUI를 다시 불러와야 EXBoss에 완전히 적용됩니다.")
      self.b1.label:SetText("지금 다시 불러오기"); self.b2.label:SetText("나중에"); self.b3:Hide()
    elseif s.ready and s.active then
      self.body:SetText("지금 Nini_S2를 쓰고 있습니다.\n\n「원래대로」를 누르면 Nini_S2를 쓰기 전 EXBoss 쐐기 설정과 음성팩으로 돌아갑니다.")
      self.b1.label:SetText("원래대로"); self.b2.label:SetText("닫기"); self.b3:Hide()
    else
      self.body:SetText("니니가 쓰는 EXBoss 쐐기 알림 설정입니다. Naowh 프로필을 바탕으로 음성만 EXBoss 음성팩으로 바꿨어요.\n\n"
        .. "· 쐐기 탱커/딜러/힐러 설정이 Nini_S2로 바뀝니다\n"
        .. "· EXBoss 음성팩을 영어로 바꿉니다\n"
        .. "· 지금 설정은 저장해 두고, /nini exboss off 로 언제든 되돌립니다")
      self.b1.label:SetText("쓰기"); self.b2.label:SetText("나중에"); self.b3.label:SetText("안 씀"); self.b3:Show()
    end
    self.status:SetText("|cff7d94a8" .. M:StatusLine() .. "|r")
  end

  function f:OnButton(i)
    local mode = self.mode
    self:Hide()
    if mode == "reload" then
      if i == 1 and type(ReloadUI) == "function" then ReloadUI() end
      return
    end
    if M:IsActive() then
      if i == 1 then M:Restore() end
      return
    end
    local d = db()
    if i == 1 then
      M:Apply()
    elseif i == 2 then
      d.decided = "later"; d.laterAt = now()
      NT:Print("Nini_S2는 다음 접속 때 다시 물어볼게요. 바로 하려면 /nini exboss")
    else
      d.decided = "never"
      NT:Print("Nini_S2를 쓰지 않습니다. 나중에 쓰려면 /nini exboss")
    end
  end

  f:Hide()
  return f
end

function M:OpenDialog()
  if not self:IsReady() then NT:Print("EXBoss가 없거나 아직 준비되지 않았습니다."); return end
  local f = self:BuildDialog()
  f.mode = "choose"
  f:Refresh()
  f:Show()
end

function M:ShouldAsk()
  if not self:IsReady() or self:IsActive() then return false end
  local d = db()
  if d.decided == "use" or d.decided == "never" then return false end
  if d.decided == "later" and (now() - (tonumber(d.laterAt) or 0)) < LATER_SECONDS then return false end
  return true
end

function M:MaybeAsk()
  if not self:ShouldAsk() or inCombat() then return end
  if type(IsInInstance) == "function" and IsInInstance() then return end
  self:OpenDialog()
end

---------------------------------------------------------------------------
-- /nini exboss
---------------------------------------------------------------------------
function M:Slash(arg)
  arg = tostring(arg or ""):lower():match("^%s*(.-)%s*$")
  if arg == "on" or arg == "use" then
    self:Apply()
  elseif arg == "off" or arg == "restore" then
    self:Restore()
  elseif arg == "eng" or arg == "english" or arg == "영어" then
    self:UseEnglishVoice()
  elseif arg == "status" then
    NT:Print(self:StatusLine())
    for _, w in ipairs(self:Warnings()) do NT:Print("|cffffc857안내|r " .. w) end
  elseif arg == "" then
    self:OpenDialog()
  else
    NT:Print("명령: /nini exboss · on · off · status · eng")
  end
end

local runner = NT.EventDispatcher and NT.EventDispatcher:CreateProxy("ExbossS2")
if runner then
  runner:RegisterEvent("PLAYER_ENTERING_WORLD")
  runner:SetScript("OnEvent", function(self, _, isInitialLogin)
    if not isInitialLogin then return end
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    if C_Timer and C_Timer.After then
      C_Timer.After(12, function() pcall(M.MaybeAsk, M) end)
    end
  end)
end
