/**
 *      Config object for `FixFFHack_Feature`.
 *      Copyright 2021-2022 Anton Tarasenko
 *------------------------------------------------------------------------------
 * This file is part of Acedia.
 *
 * Acedia is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License, or
 * (at your option) any later version.
 *
 * Acedia is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Acedia.  If not, see <https://www.gnu.org/licenses/>.
 */
class FixFFHack extends FeatureConfig
    perobjectconfig
    config(AcediaFixes);

var public config bool                          scaleByDefault;
var public config array< class<DamageType> >    alwaysScale;
var public config array< class<DamageType> >    neverScale;

protected function HashTable ToData()
{
    local int       i;
    local HashTable data;
    local ArrayList damageTypeArray;
    data = _.collections.EmptyHashTable();
    data.SetBool(P("scaleByDefault"), scaleByDefault);
    damageTypeArray = _.collections.EmptyArrayList();
    for (i = 0; i < alwaysScale.length; i += 1) {
        damageTypeArray.AddString(string(alwaysScale[i]));
    }
    data.SetItem(P("alwaysScale"), damageTypeArray);
    _.memory.Free(damageTypeArray);
    damageTypeArray = _.collections.EmptyArrayList();
    for (i = 0; i < neverScale.length; i += 1) {
        damageTypeArray.AddString(string(neverScale[i]));
    }
    data.SetItem(P("neverScale"), damageTypeArray);
    _.memory.Free(damageTypeArray);
    return data;
}

protected function FromData(HashTable source)
{
    local int       i;
    local ArrayList damageTypeArray;
    if (source == none) {
        return;
    }
    scaleByDefault = source.GetBool(P("scaleByDefault"));
    alwaysScale.length = 0;
    damageTypeArray = source.GetArrayList(P("alwaysScale"));
    if (damageTypeArray != none) {
        for (i = 0; i < damageTypeArray.GetLength(); i += 1)
        {
            alwaysScale[i] = class<DamageType>(
                _.memory.LoadClass_S(damageTypeArray.GetString(i)));
        }
    }
    _.memory.Free(damageTypeArray);
    neverScale.length = 0;
    damageTypeArray = source.GetArrayList(P("neverScale"));
    if (damageTypeArray != none) {
        for (i = 0; i < damageTypeArray.GetLength(); i += 1)
        {
            neverScale[i] = class<DamageType>(
                _.memory.LoadClass_S(damageTypeArray.GetString(i)));
        }
    }
    _.memory.Free(damageTypeArray);
}

protected function DefaultIt()
{
    scaleByDefault      = false;
    alwaysScale.length  = 0;
    neverScale.length   = 0;
    //  Vanilla damage types for projectiles
    alwaysScale[0]  = class'KFMod.DamTypeCrossbuzzsawHeadShot';
    alwaysScale[1]  = class'KFMod.DamTypeCrossbuzzsaw';
    alwaysScale[2]  = class'KFMod.DamTypeFrag';
    alwaysScale[3]  = class'KFMod.DamTypePipeBomb';
    alwaysScale[4]  = class'KFMod.DamTypeM203Grenade';
    alwaysScale[5]  = class'KFMod.DamTypeM79Grenade';
    alwaysScale[6]  = class'KFMod.DamTypeM79GrenadeImpact';
    alwaysScale[7]  = class'KFMod.DamTypeM32Grenade';
    alwaysScale[8]  = class'KFMod.DamTypeLAW';
    alwaysScale[9]  = class'KFMod.DamTypeLawRocketImpact';
    alwaysScale[10] = class'KFMod.DamTypeFlameNade';
    alwaysScale[11] = class'KFMod.DamTypeFlareRevolver';
    alwaysScale[12] = class'KFMod.DamTypeFlareProjectileImpact';
    alwaysScale[13] = class'KFMod.DamTypeBurned';
    alwaysScale[14] = class'KFMod.DamTypeTrenchgun';
    alwaysScale[15] = class'KFMod.DamTypeHuskGun';
    alwaysScale[16] = class'KFMod.DamTypeCrossbow';
    alwaysScale[17] = class'KFMod.DamTypeCrossbowHeadShot';
    alwaysScale[18] = class'KFMod.DamTypeM99SniperRifle';
    alwaysScale[19] = class'KFMod.DamTypeM99HeadShot';
    alwaysScale[20] = class'KFMod.DamTypeShotgun';
    alwaysScale[21] = class'KFMod.DamTypeNailGun';
    alwaysScale[22] = class'KFMod.DamTypeDBShotgun';
    alwaysScale[23] = class'KFMod.DamTypeKSGShotgun';
    alwaysScale[24] = class'KFMod.DamTypeBenelli';
    alwaysScale[25] = class'KFMod.DamTypeSPGrenade';
    alwaysScale[26] = class'KFMod.DamTypeSPGrenadeImpact';
    alwaysScale[27] = class'KFMod.DamTypeSeekerSixRocket';
    alwaysScale[28] = class'KFMod.DamTypeSeekerRocketImpact';
    alwaysScale[29] = class'KFMod.DamTypeSealSquealExplosion';
    alwaysScale[30] = class'KFMod.DamTypeRocketImpact';
    alwaysScale[31] = class'KFMod.DamTypeBlowerThrower';
    alwaysScale[32] = class'KFMod.DamTypeSPShotgun';
    alwaysScale[33] = class'KFMod.DamTypeZEDGun';
    alwaysScale[34] = class'KFMod.DamTypeZEDGunMKII';
}

defaultproperties
{
    configName = "AcediaFixes"
    scaleByDefault  = false
    //  Vanilla damage types for projectiles
    alwaysScale(0)  = class'KFMod.DamTypeCrossbuzzsawHeadShot'
    alwaysScale(1)  = class'KFMod.DamTypeCrossbuzzsaw'
    alwaysScale(2)  = class'KFMod.DamTypeFrag'
    alwaysScale(3)  = class'KFMod.DamTypePipeBomb'
    alwaysScale(4)  = class'KFMod.DamTypeM203Grenade'
    alwaysScale(5)  = class'KFMod.DamTypeM79Grenade'
    alwaysScale(6)  = class'KFMod.DamTypeM79GrenadeImpact'
    alwaysScale(7)  = class'KFMod.DamTypeM32Grenade'
    alwaysScale(8)  = class'KFMod.DamTypeLAW'
    alwaysScale(9)  = class'KFMod.DamTypeLawRocketImpact'
    alwaysScale(10) = class'KFMod.DamTypeFlameNade'
    alwaysScale(11) = class'KFMod.DamTypeFlareRevolver'
    alwaysScale(12) = class'KFMod.DamTypeFlareProjectileImpact'
    alwaysScale(13) = class'KFMod.DamTypeBurned'
    alwaysScale(14) = class'KFMod.DamTypeTrenchgun'
    alwaysScale(15) = class'KFMod.DamTypeHuskGun'
    alwaysScale(16) = class'KFMod.DamTypeCrossbow'
    alwaysScale(17) = class'KFMod.DamTypeCrossbowHeadShot'
    alwaysScale(18) = class'KFMod.DamTypeM99SniperRifle'
    alwaysScale(19) = class'KFMod.DamTypeM99HeadShot'
    alwaysScale(20) = class'KFMod.DamTypeShotgun'
    alwaysScale(21) = class'KFMod.DamTypeNailGun'
    alwaysScale(22) = class'KFMod.DamTypeDBShotgun'
    alwaysScale(23) = class'KFMod.DamTypeKSGShotgun'
    alwaysScale(24) = class'KFMod.DamTypeBenelli'
    alwaysScale(25) = class'KFMod.DamTypeSPGrenade'
    alwaysScale(26) = class'KFMod.DamTypeSPGrenadeImpact'
    alwaysScale(27) = class'KFMod.DamTypeSeekerSixRocket'
    alwaysScale(28) = class'KFMod.DamTypeSeekerRocketImpact'
    alwaysScale(29) = class'KFMod.DamTypeSealSquealExplosion'
    alwaysScale(30) = class'KFMod.DamTypeRocketImpact'
    alwaysScale(31) = class'KFMod.DamTypeBlowerThrower'
    alwaysScale(32) = class'KFMod.DamTypeSPShotgun'
    alwaysScale(33) = class'KFMod.DamTypeZEDGun'
    alwaysScale(34) = class'KFMod.DamTypeZEDGunMKII'
}