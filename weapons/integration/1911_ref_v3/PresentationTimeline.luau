--!strict
-- Cosmetic timeline only. Call after the existing local eligibility check.
-- Never awards ammo, changes movement, sends remotes, or decides damage.
local Timeline = {}
Timeline.__index = Timeline
local function zero() return {0, 0, 0, 0, 0, 0} end
local function mix(a, b, t)
    local v = {}
    for i = 1, 6 do v[i] = a[i] + (b[i] - a[i]) * t end
    return v
end
local function sample(keys, t)
    if t <= keys[1][1] then return keys[1][2] end
    for i = 2, #keys do
        local a, b = keys[i-1], keys[i]
        if t <= b[1] then
            local k = math.clamp((t-a[1])/(b[1]-a[1]), 0, 1)
            k = k*k*(3-2*k)
            return mix(a[2], b[2], k)
        end
    end
    return keys[#keys][2]
end
local function validate(track)
    assert(type(track.Duration)=="number" and track.Duration>0, "Invalid duration")
    for _, keys in track.Poses do
        assert(#keys>=2 and keys[1][1]==0, "Track must begin at zero")
        local last=-1
        for _, key in keys do
            assert(key[1]>last and key[1]<=track.Duration, "Invalid key order")
            last=key[1]
            assert(#key[2]==6, "Pose must have six channels")
            for _, value in key[2] do assert(value==value and math.abs(value)<1e6,"Invalid pose") end
        end
        assert(last==track.Duration,"All channels must end at duration")
        for _, value in keys[#keys][2] do assert(value==0,"Track must end at rest") end
    end
    local last=-1
    for _, marker in track.Markers or {} do
        assert(marker.Time>=0 and marker.Time<=track.Duration and marker.Time>=last,"Invalid marker")
        last=marker.Time
    end
end
function Timeline.new(tracks)
    for _, track in tracks do validate(track) end
    return setmetatable({tracks=tracks,active=nil,elapsed=0,entry={},release=nil},Timeline)
end
function Timeline:GetPose()
    local result={}
    if self.active then
        for joint, keys in self.active.Poses do
            local pose=sample(keys,self.elapsed)
            local displaced=false
            for _, v in self.entry[joint] or {} do if math.abs(v)>1e-4 then displaced=true break end end
            local blend=math.clamp(self.elapsed/((displaced and self.blendIn) or self.active.BlendIn or .045),0,1)
            blend=blend*blend*(3-2*blend)
            result[joint]=mix(self.entry[joint] or zero(),pose,blend)
        end
        -- A displaced joint from the interrupted track returns smoothly as well.
        for joint, pose in self.entry do
            if not result[joint] then
                local k=math.clamp(self.elapsed/.07,0,1);result[joint]=mix(pose,zero(),k*k*(3-2*k))
            end
        end
    elseif self.release then
        local k=math.clamp(self.release.time/.10,0,1);k=k*k*(3-2*k)
        for joint, pose in self.release.poses do result[joint]=mix(pose,zero(),k) end
    end
    return result
end
function Timeline:Play(name)
    local track=self.tracks[name]
    if not track then return false end
    -- Inspection cannot interrupt firing/equip. Combat can always interrupt inspection.
    if name=="Inspect" and self.active and self.action~="Inspect" then return false end
    self.entry=self:GetPose()
    -- Claude 2026-11-02: a shot that cuts off a large pose (inspect/equip) eases the displaced
    -- joints (Root/SupportHand) out of it over INTERRUPT_BLEND instead of the track's near-instant
    -- BlendIn, so the gun no longer snaps ~30 degrees in one frame. Joints at rest (slide, hammer,
    -- trigger) keep the track's own BlendIn, so slide travel is unchanged. Effects/combat timing
    -- are unaffected (they never wait on this).
    local INTERRUPT_BLEND=.06
    self.blendIn=nil
    if self.active and (self.action=="Inspect" or self.action=="Equip") and name~=self.action then
        self.blendIn=math.max(track.BlendIn or .045,INTERRUPT_BLEND)
    end
    if track.StartAtFirstKey and not self.active and not self.release then
        for joint, keys in track.Poses do self.entry[joint]=keys[1][2] end
    end
    self.release=nil;self.active=track;self.action=name;self.elapsed=0
    self.marker=0
    return true
end
function Timeline:Cancel()
    self.release={poses=self:GetPose(),time=0}
    self.active=nil;self.action=nil;self.entry={}
end
function Timeline:Reset()
    self.active=nil;self.action=nil;self.entry={};self.release=nil;self.elapsed=0;self.marker=0
end
function Timeline:Step(dt)
    assert(type(dt)=="number" and dt==dt and dt>=0 and dt<math.huge,"Invalid delta time")
    local events={}
    if self.active then
        -- Do not clamp dt: a slow frame must not lose timeline markers.
        self.elapsed=math.min(self.elapsed+dt,self.active.Duration)
        local markers=self.active.Markers or {}
        while self.marker<#markers and markers[self.marker+1].Time<=self.elapsed do
            self.marker+=1;table.insert(events,markers[self.marker].Cue)
        end
        if self.elapsed>=self.active.Duration then
            self.active=nil;self.action=nil;self.entry={}
        end
    elseif self.release then
        self.release.time+=dt
        if self.release.time>=.10 then self.release=nil end
    end
    return self:GetPose(),events
end
return Timeline
