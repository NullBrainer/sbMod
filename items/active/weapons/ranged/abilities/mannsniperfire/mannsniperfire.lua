require "/scripts/util.lua"
require "/scripts/interp.lua"

-- CustomScript for mann shotgun
MannSniperFire = WeaponAbility:new()
CritActive = false
ZoomedIn = false
soundPlayed = false
function MannSniperFire:init()
	self.weapon:setStance(self.stances.idle)

	self.bulletCount = config.getParameter("bulletCount",0)
	self:SetGunState()
    
	self.cooldownTimer = self.fireTime
	self.chargeTime = 0
	storage.zoomChangeTime = 0
  

  
	self.weapon.onLeaveAbility = function()
		self.weapon:setStance(self.stances.idle)
	end
end

function MannSniperFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)  
  mcontroller.controlModifiers({runningSuppressed = ZoomedIn})
  self.chargeTime = math.max(0,self.chargeTime - self.dt)
  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)  	
  storage.zoomChangeTime = math.max(0, storage.zoomChangeTime - self.dt)
	
  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end
  
  if self.chargeTime == 0 
  and ZoomedIn then
  if not soundPlayed then
  animator.playSound("charged")
  soundPlayed = true
  end
  CritActive = true  
  else
  CritActive = false
  end
  
	if (self.bulletCount == 0)
	and self.fireMode == "primary" 
	and not self.weapon.currentAbility then
	
		self:setState(self.emptyFire)
	
	elseif (self.bulletCount < self.maxAmmo) 
	and self.fireMode == "alt"
	and not self.weapon.currentAbility then

		self:setState(self.reload)
		storage.zoomChangeTime = 0.5
	
	elseif self.fireMode == "alt" 
	and (self.bulletCount > 0)
	and not ZoomedIn
	and storage.zoomChangeTime == 0
    and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then

	self:setCharge()
	
	elseif fireMode == "alt"
	and ZoomedIn
	and storage.zoomChangeTime == 0	then

		storage.zoomChangeTime = 0.5
		ZoomedIn = false	

	
	elseif self.fireMode == "primary"
	and (self.bulletCount > 0)
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
    and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then

		if self.fireType == "auto" then
		
			self:setState(self.auto)
			ZoomedIn = false
			
		end
	end
end


function MannSniperFire:auto()
  self.weapon:setStance(self.stances.fire)
	if(CritActive == true) then		
		animator.playSound("critfire")
	else
		  animator.playSound("fire")
	end
	
	self:muzzleFlash()
	self:fireProjectile()
	
	self.bulletCount = self.bulletCount - 1
	activeItem.setInstanceValue("bulletCount", self.bulletCount)

  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end
self:setState(self.cooldown)
  
end

 
function MannSniperFire:cooldown()
  self.weapon:setStance(self.stances.cooldown)
  self.weapon:updateAim()

  local progress = 0
  util.wait(self.stances.cooldown.duration, function()
    local from = self.stances.cooldown.weaponOffset or {0,0}
    local to = self.stances.idle.weaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.weaponRotation, self.stances.idle.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.armRotation, self.stances.idle.armRotation))

    progress = math.min(1.0, progress + (self.dt / self.stances.cooldown.duration))
  end)
end

function MannSniperFire:reload()
    
  self.bulletCount = self.bulletCount + 1
  activeItem.setInstanceValue("bulletCount", self.bulletCount)	
  self:SetGunState()
  animator.playSound("reload")
  self.weapon:setStance(self.stances.reload)
  
	if self.stances.reload.duration then
		util.wait(self.stances.reload.duration)    
	end


  end



function MannSniperFire:emptyFire()
animator.playSound("empty")
self.weapon:setStance(self.stances.emptyfire)
if self.stances.emptyfire.duration then
util.wait(self.stances.emptyfire.duration)
  end

end

function MannSniperFire:setCharge()
self.chargeTime = config.getParameter("chargeTime", 3.3)
storage.zoomChangeTime = 0.5
ZoomedIn = true
soundPlayed = false


end

function MannSniperFire:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
  animator.setAnimationState("firing", "fire")
  animator.burstParticleEmitter("muzzleFlash")
  animator.setLightActive("muzzleFlash", true)
end

function MannSniperFire:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
  local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
  if self.chargeTime  == 0 and ZoomedIn then
	params = sb.jsonMerge(self.critprojectileParameters)
	params.powerMultiplier = 9
	elseif self.chargeTime >= 0 and ZoomedIn then
	params.powerMultiplier = 3
  else
    params.powerMultiplier = 1
  end
    params.power = self:damagePerShot()
  params.speed = util.randomInRange(params.speed)

  if not projectileType then
	if CritActive then
	projectileType = self.critProjectile
    else
	projectileType = self.projectileType
	end
  end
  if type(projectileType) == "table" then
    projectileType = projectileType[math.random(#projectileType)]
  end

  local projectileId = 0
  for i = 1, (projectileCount or self.projectileCount) do
    if params.timeToLive then
      params.timeToLive = util.randomInRange(params.timeToLive)
    end

    projectileId = world.spawnProjectile(
        projectileType,
        firePosition or self:firePosition(),
        activeItem.ownerEntityId(),
        self:aimVector(inaccuracy or self.inaccuracy),
        false,
        params
      )
  end
  return projectileId
end

function MannSniperFire:SetGunState()
local ammo = self.bulletCount

self.bulletCount = ammo

return self.bulletCount
end

function MannSniperFire:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function MannSniperFire:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function MannSniperFire:energyPerShot()
  return status.resourceMax("energy")/self.shotsperreload
end

function MannSniperFire:damagePerShot()
  return (self.baseDamage or (self.baseDps * self.fireTime)) / self.projectileCount
end

function MannSniperFire:uninit()
end
