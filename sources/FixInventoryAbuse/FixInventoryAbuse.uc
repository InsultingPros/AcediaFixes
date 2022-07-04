/**
 *      Config object for `FixInventoryAbuse_Feature`.
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
class FixInventoryAbuse extends FeatureConfig
    perobjectconfig
    config(AcediaFixes)
    dependson(FixInventoryAbuse_Feature);

var public config float                                         checkInterval;
var public config array<FixInventoryAbuse_Feature.DualiesPair>  dualiesClasses;

protected function HashTable ToData()
{
    local int       i;
    local ArrayList pairsArray;
    local HashTable data, pair;
    data = _.collections.EmptyHashTable();
    data.SetFloat(P("checkInterval"), checkInterval);
    pairsArray = _.collections.EmptyArrayList();
    for (i = 0; i < dualiesClasses.length; i += 1)
    {
        pair = _.collections.EmptyHashTable();
        pair.SetItem(   P("single"),
                        _.text.FromString(string(dualiesClasses[i].single)));
        pair.SetItem(   P("dual"),
                        _.text.FromString(string(dualiesClasses[i].dual)));
        pairsArray.AddItem(pair);
    }
    data.SetItem(P("dualiesClasses"), pairsArray);
    _.memory.Free(pairsArray);  
    return data;
}

protected function FromData(HashTable source)
{
    local int                                   i;
    local ArrayList                             pairsArray;
    local HashTable                             loadedPair;
    local FixInventoryAbuse_Feature.DualiesPair newPair;
    if (source == none) {
        return;
    }
    checkInterval = source.GetFloat(P("checkInterval"), 0.25);
    pairsArray = source.GetArrayList(P("dualiesClasses"));
    dualiesClasses.length = 0;
    if (pairsArray == none) {
        return;
    }
    for (i = 0; i < pairsArray.GetLength(); i += 1)
    {
        loadedPair = pairsArray.GetHashTable(i);
        if (loadedPair == none) continue;

        newPair.single = class<KFWeaponPickup>(
            _.memory.LoadClass(loadedPair.GetText(P("single"))) );
        newPair.dual = class<KFWeaponPickup>(
            _.memory.LoadClass(loadedPair.GetText(P("dual"))) );
        dualiesClasses[dualiesClasses.length] = newPair;
    }
    _.memory.Free(pairsArray);
}

protected function DefaultIt()
{
    local FixInventoryAbuse_Feature.DualiesPair newPair;
    checkInterval = 0.25;
    dualiesClasses.length = 0;
    newPair.single  = class'KFMod.SinglePickup';
    newPair.dual    = class'KFMod.DualiesPickup';
    dualiesClasses[dualiesClasses.length] = newPair;
    newPair.single  = class'KFMod.Magnum44Pickup';
    newPair.dual    = class'KFMod.Dual44MagnumPickup';
    dualiesClasses[dualiesClasses.length] = newPair;
    newPair.single  = class'KFMod.MK23Pickup';
    newPair.dual    = class'KFMod.DualMK23Pickup';
    dualiesClasses[dualiesClasses.length] = newPair;
    newPair.single  = class'KFMod.DeaglePickup';
    newPair.dual    = class'KFMod.DualDeaglePickup';
    dualiesClasses[dualiesClasses.length] = newPair;
    newPair.single  = class'KFMod.GoldenDeaglePickup';
    newPair.dual    = class'KFMod.GoldenDualDeaglePickup';
    dualiesClasses[dualiesClasses.length] = newPair;
    newPair.single  = class'KFMod.FlareRevolverPickup';
    newPair.dual    = class'KFMod.DualFlareRevolverPickup';
    dualiesClasses[dualiesClasses.length] = newPair;
}

defaultproperties
{
    configName = "AcediaFixes"
    checkInterval = 0.25
    dualiesClasses(0)=(single=class'KFMod.SinglePickup',dual=class'KFMod.DualiesPickup')
    dualiesClasses(1)=(single=class'KFMod.Magnum44Pickup',dual=class'KFMod.Dual44MagnumPickup')
    dualiesClasses(2)=(single=class'KFMod.MK23Pickup',dual=class'KFMod.DualMK23Pickup')
    dualiesClasses(3)=(single=class'KFMod.DeaglePickup',dual=class'KFMod.DualDeaglePickup')
    dualiesClasses(4)=(single=class'KFMod.GoldenDeaglePickup',dual=class'KFMod.GoldenDualDeaglePickup')
    dualiesClasses(5)=(single=class'KFMod.FlareRevolverPickup',dual=class'KFMod.DualFlareRevolverPickup')
}