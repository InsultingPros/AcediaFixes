/**
 *      Config object for `FixAmmoSelling_Feature`.
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
class FixAmmoSelling extends FeatureConfig
    perobjectconfig
    config(AcediaFixes);

var public config bool allowNegativeDosh;

protected function AssociativeArray ToData()
{
    local AssociativeArray data;
    data = __().collections.EmptyAssociativeArray();
    data.SetBool(P("allowNegativeDosh"), allowNegativeDosh, true);
    return data;
}

protected function FromData(AssociativeArray source)
{
    if (source != none) {
        allowNegativeDosh = source.GetBool(P("allowNegativeDosh"));
    }
}

protected function DefaultIt()
{
    allowNegativeDosh = false;
}

defaultproperties
{
    configName = "AcediaFixes"
    allowNegativeDosh = false
}