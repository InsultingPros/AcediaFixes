/**
 *      Config object for `FixPipes_Feature`.
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
class FixPipes extends FeatureConfig
    perobjectconfig
    config(AcediaFixes);

var public config bool  preventMassiveDamage;
var public config bool  preventSuspiciousDamage;
var public config bool  preventCorpseDetonation;
var public config bool  preventNPCDetonation;
var public config float proximityCheckElevation;

protected function HashTable ToData()
{
    local HashTable data;
    data = __().collections.EmptyHashTable();
    data.SetBool(P("preventMassiveDamage"), preventMassiveDamage);
    data.SetBool(P("preventSuspiciousDamage"), preventSuspiciousDamage);
    data.SetBool(P("preventCorpseDetonation"), preventCorpseDetonation);
    data.SetBool(P("preventNPCDetonation"), preventNPCDetonation);
    data.SetFloat(P("proximityCheckElevation"), proximityCheckElevation);
    return data;
}

protected function FromData(HashTable source)
{
    if (source == none) {
        return;
    }
    preventMassiveDamage = source.GetBool(P("preventMassiveDamage"));
    preventSuspiciousDamage = source.GetBool(P("preventSuspiciousDamage"));
    preventCorpseDetonation = source.GetBool(P("preventCorpseDetonation"));
    preventNPCDetonation = source.GetBool(P("preventNPCDetonation"));
    proximityCheckElevation = source.GetFloat(P("proximityCheckElevation"), 20);
}

protected function DefaultIt()
{
    preventMassiveDamage    = true;
    preventSuspiciousDamage = true;
    preventCorpseDetonation = true;
    preventNPCDetonation    = true;
    proximityCheckElevation = 20.0;
}

defaultproperties
{
    configName = "AcediaFixes"
    preventMassiveDamage    = true
    preventSuspiciousDamage = true
    preventCorpseDetonation = true
    preventNPCDetonation    = true
    proximityCheckElevation = 20.0
}