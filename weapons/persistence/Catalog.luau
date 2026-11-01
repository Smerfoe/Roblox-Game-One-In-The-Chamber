-- Draft prices; no automatic coin earnings or paid crates are enabled.
local Catalog = {
    MaxCoins = 2147483647,
    ReceiptLimit = 32,
    Items = {
        Service1911 = { Slot = "Pistol", Price = 0, Default = true },
        OldWestRevolver = { Slot = "Pistol", Price = 2500 },
        HeavyEagle = { Slot = "Pistol", Price = 7000 },
        PythonMagnum = { Slot = "Pistol", Price = 10000 },
        FrontierRepeater = { Slot = "Pistol", Price = 100000 },
        BasicKnife = { Slot = "Knife", Default = true },
        Karambit = { Slot = "Knife" },
        ButterflyKnife = { Slot = "Knife" },
        Machete = { Slot = "Knife" },
        TrailBowie = { Slot = "Knife" },
    },
    Crates = {
        TestBlades = {
            Price = 10, StudioOnly = true,
            -- Equal integer buckets: 25% each. No client supplies the roll.
            Items = { "Karambit", "ButterflyKnife", "Machete", "TrailBowie" },
        },
    },
    CreditSources = { Match = true, AdminGrant = true, Migration = true },
}
local function freeze(t)
    for _, value in pairs(t) do
        if type(value) == "table" then freeze(value) end
    end
    return table.freeze(t)
end
return freeze(Catalog)
