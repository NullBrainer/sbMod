require "/scripts/util.lua"
require "/scripts/interp.lua"

-- Base gun fire ability
MannGunFire = WeaponAbility:new()
CritActive = false
timedCrits = false
determinant = math.random()
function MannGunFire:init()
  self.weapon:setStance(self.stances.idle)

  self.cooldownTimer = self.fireTime
  critChance = self.critChance/100.00
  timedCrits = self.timedCrits or false
  self.threadState = coroutine.create(critfunction)

  
  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
end

function MannGunFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)  
  if timedCrits == true and  coroutine.status(self.threadState) ~= "running" then
  self:timedCritShots(critfunction)
  end
  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)  	
	
  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end
  
  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy")
    and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then

    if self.fireType == "auto" and status.overConsumeResource("energy", self:energyPerShot()) then
	
	if timedCrits == false then
		self:critShot()	
	end
	
      self:setState(self.auto)
    elseif self.fireType == "burst" then
      self:setState(self.burst)
    end
  end
end

function MannGunFire:critShot()
local critvalue = math.random()
CritActive = (critvalue < critChance)
end

function MannGunFire:timedCritShots(critfunction)
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

function MannGunFire:auto()
  self.weapon:setStance(self.stances.fire)
	if(CritActive == true) then		
		animator.playSound("critfire")
	else
		  animator.playSound("fire")
	end

	self:muzzleFlash()
	self:fireProjectile()
  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end

  self.cooldownTimer = self.fireTime
  self:setState(self.cooldown)
end

function MannGunFire:burst()
  self.weapon:setStance(self.stances.fire)

  local shots = self.burstCount
  while shots > 0 and status.overConsumeResource("energy", self:energyPerShot()) do
    self:fireProjectile()
    self:muzzleFlash()
    shots = shots - 1

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(1 - shots / self.burstCount, 0, self.stances.fire.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(1 - shots / self.burstCount, 0, self.stances.fire.armRotation))

    util.wait(self.burstTime)
  end

  self.cooldownTimer = (self.fireTime - self.burstTime) * self.burstCount
end

function MannGunFire:cooldown()
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

function MannGunFire:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
  animator.setAnimationState("firing", "fire")
  animator.burstParticleEmitter("muzzleFlash")
  animator.setLightActive("muzzleFlash", true)
end

function MannGunFire:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
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

function MannGunFire:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function MannGunFire:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function MannGunFire:energyPerShot()
  return status.resourceMax("energy")/self.shotsperreload
end

function MannGunFire:damagePerShot()
  return (self.baseDamage or (self.baseDps * self.fireTime)) / self.projectileCount
end

function MannGunFire:uninit()
end
