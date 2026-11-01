-- Development armory. Prices are the user's draft coin ladder.
local C={
 Service1911={Name="Service 1911",Slot="Pistol",Price=0,Default=true},
 OldWestRevolver={Name="Western Revolver",Slot="Pistol",Price=2500,Model="OldWestRevolver_Prototype"},
 HeavyEagle={Name="Heavy Eagle",Slot="Pistol",Price=7000,Model="HeavyEagle_Prototype"},
 PythonMagnum={Name="Python Magnum",Slot="Pistol",Price=10000,Model="PythonMagnum_Prototype"},
 FrontierRepeater={Name="Frontier Repeater",Slot="Pistol",Price=100000,Model="FrontierRepeater_Prototype"},
 BasicKnife={Name="Basic Knife",Slot="Knife",Default=true,Model="ButterKnife_Prototype"},
 Karambit={Name="Karambit",Slot="Knife",Crate=true},
 ButterflyKnife={Name="Butterfly Knife",Slot="Knife",Crate=true,Model="ButterflyKnife_Prototype"},
 Machete={Name="Machete",Slot="Knife",Crate=true,Model="Machete_Prototype"},
 TrailBowie={Name="Trail Bowie",Slot="Knife",Crate=true,Model="TrailBowie_Prototype"},
}
for _,v in C do table.freeze(v) end
return table.freeze(C)
