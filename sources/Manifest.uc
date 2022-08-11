/**
 *      Manifest for AcediaFixes package
 *      Copyright 2020 - 2021 Anton Tarasenko
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
class Manifest extends _manifest
    abstract;

defaultproperties
{
    features(0)     = class'FixZedTimeLags_Feature'
    features(1)     = class'FixDoshSpam_Feature'
    features(2)     = class'FixFFHack_Feature'
    features(3)     = class'FixInfiniteNades_Feature'
    features(4)     = class'FixAmmoSelling_Feature'
    features(5)     = class'FixSpectatorCrash_Feature'
    features(6)     = class'FixDualiesCost_Feature'
    features(7)     = class'FixInventoryAbuse_Feature'
    features(8)     = class'FixProjectileFF_Feature'
    features(9)     = class'FixLogSpam_Feature'
    //features(9)     = class'FixPipes_Feature'
}