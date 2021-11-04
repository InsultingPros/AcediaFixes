/**
 *      Service for storing `FixAmmoSelling`'s `Actor`s.
 *      Copyright 2021 Anton Tarasenko
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
class FixAmmoSellingService extends FeatureService
    dependson(FixAmmoSelling_Feature);

var private FixAmmoSelling_Feature ammoSellingFix;

//      All weapons we've detected so far.
//      Made `public` to avoid needless calls, since this is not part of
//  a library's interface anyway.
var public array<FixAmmoSelling_Feature.WeaponRecord> registeredWeapons; 

protected function Finalizer()
{
    ammoSellingFix = none;
}

public function SetOwnerFeature(Feature newOwnerFeature)
{
    super.SetOwnerFeature(newOwnerFeature);
    ammoSellingFix = FixAmmoSelling_Feature(newOwnerFeature);
}

event Tick(float delta)
{
    local int i;
    if (ammoSellingFix == none) {
        return;
    }
    //  For all the weapon records...
    i = 0;
    while (i < registeredWeapons.length)
    {
        //  ...remove dead records
        if (registeredWeapons[i].weapon == none)
        {
            registeredWeapons.Remove(i, 1);
            continue;
        }
        //  ...find ammo if it's missing
        if (registeredWeapons[i].ammo == none)
        {
            registeredWeapons[i] =
                ammoSellingFix.FindAmmoInstance(registeredWeapons[i]);
        }
        //  ...tax for ammo, if we can
        registeredWeapons[i] =
            ammoSellingFix.TaxAmmoChange(registeredWeapons[i]);
        i += 1;
    }
}

defaultproperties
{
}