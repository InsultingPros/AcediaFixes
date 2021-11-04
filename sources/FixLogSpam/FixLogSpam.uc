/**
 *      Config object for `FixLogSpam_Feature`.
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
class FixLogSpam extends FeatureConfig
    perobjectconfig
    config(AcediaFixes);

var public config bool fixPickupSpam;
var public config bool fixTraderSpam;

protected function AssociativeArray ToData()
{
    local AssociativeArray data;
    data = __().collections.EmptyAssociativeArray();
    data.SetBool(P("fixPickupSpam"), fixPickupSpam, true);
    data.SetBool(P("fixTraderSpam"), fixTraderSpam, true);
    return data;
}

protected function FromData(AssociativeArray source)
{
    if (source != none)
    {
        fixPickupSpam = source.GetBool(P("fixPickupSpam"), true);
        fixTraderSpam = source.GetBool(P("fixTraderSpam"), true);
    }
}

protected function DefaultIt()
{
    fixPickupSpam = true;
    fixTraderSpam = true;
}

defaultproperties
{
    configName = "AcediaFixes"
    fixPickupSpam = true
    fixTraderSpam = true
}