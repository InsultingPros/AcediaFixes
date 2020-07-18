/**
 *      Manifest for AcediaFixes package
 *      Copyright 2020 Anton Tarasenko
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
    features(0) = class'FixZedTimeLags'
    features(1) = class'FixDoshSpam'
    features(2) = class'FixFFHack'
    features(3) = class'FixInfiniteNades'
    features(4) = class'FixAmmoSelling'
    features(5) = class'FixSpectatorCrash'
    features(6) = class'FixDualiesCost'
    features(7) = class'FixInventoryAbuse'
}