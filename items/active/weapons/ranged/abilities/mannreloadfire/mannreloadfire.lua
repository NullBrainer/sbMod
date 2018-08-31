require "/scripts/util.lua"
require "/scripts/interp.lua"

-- CustomScript for mann shotgun
MannReloadFire = WeaponAbility:new()
CritActive = false
timedCrits = false
determinant = math.random()

function MannReloadFire:init()
	self.weapon:setStance(self.stances.idle)
	
	timedCrits = self.timedCrits or false
	self.bulletCount = config.getParameter("bulletCount",0)
	self:SetGunState()
    
	self.threadState = coroutine.create(critfunction)	
	self.cooldownTimer = self.fireTime
	critChance = self.critChance/100.00
  

  
	self.weapon.onLeaveAbility = function()
		self.weapon:setStance(self.stances.idle)
	end
end

function MannReloadFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)  
  
  if timedCrits == true and coroutine.status(self.threadState) ~= "running" then
  self:timedCritShots(critfunction)
  end
  
  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)  	
	
  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end
  
  if (self.bulletCount == 0)
  and self.fireMode == "primary" 
  and not self.weapon.currentAbility then
	
	self:setState(self.emptyFire)
	
	elseif (self.bulletCount < self.maxAmmo) 
	and self.fireMode == "alt"
	and not self.weapon.currentAbility
	then

	self:setState(self.reload)
	
	
  elseif self.fireMode == "primary"
	and (self.bulletCount > 0)
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
    and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then

    if self.fireType == "auto" then
	
		if not timedCrits then
			self:critShot()	
		end
		self:setState(self.auto)
		
    
    end
	
  end
end

function MannReloadFire:timedCritShots(critfunction)
local status, result = coroutine.resume(self.threadState)
if not status then
error(result)
end
end


function critfunction()
local i = 0
	while timedCrits == true do
		util.wait(1)
		determinant = math.random()
		CritActive = determinant < critChance			
		if CritActive == true then						
			util.wait(2)
			CritActive = false
		end	
		
	end	
	
end

function MannReloadFire:critShot()
local critvalue = math.random()
CritActive = (critvalue < critChance)
end


function MannReloadFire:auto()
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
	self:SetGunState()
	
  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end
  self:setState(self.cooldown)
  
end

 
function MannReloadFire:cooldown()
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

function MannReloadFire:reload()
  
  self.bulletCount = self.maxAmmo
  activeItem.setInstanceValue("bulletCount", self.bulletCount)	
  self:SetGunState()
  
  animator.playSound("reload")
  self.weapon:setStance(self.stances.reload)
  
	if self.stances.reload.duration then
		util.wait(self.stances.reload.duration)    
	end

	self:setState(self.cooldown)
end
  

function MannReloadFire:emptyFire()
animator.playSound("empty")
self.weapon:setStance(self.stances.emptyfire)
if self.stances.emptyfire.duration then
util.wait(self.stances.emptyfire.duration)
  end

end


function MannReloadFire:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
  animator.setAnimationState("firing", "fire")
  animator.burstParticleEmitter("muzzleFlash")
  animator.setLightActive("muzzleFlash", true)
end

function MannReloadFire:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
  local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
  if CritActive then
	params = sb.jsonMerge(self.critprojectileParameters)
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

function MannReloadFire:SetGunState()
local ammo = self.bulletCount

self.bulletCount = ammo

return self.bulletCount
end

function MannReloadFire:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function MannReloadFire:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function MannReloadFire:energyPerShot()
  return status.resourceMax("energy")/self.shotsperreload
end

function MannReloadFire:damagePerShot()
  return (self.baseDamage or (self.baseDps * self.fireTime)) / self.projectileCount
end

function MannReloadFire:uninit()
end
