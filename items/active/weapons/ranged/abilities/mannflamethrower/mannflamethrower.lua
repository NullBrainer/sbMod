require "/scripts/util.lua"
require "/scripts/interp.lua"

MannFlamethrowerAttack = WeaponAbility:new()
CritActive = false
timedCrits = false
determinant = math.random()
critsoundPlaying = false
stocksoundPlaying = false
function MannFlamethrowerAttack:init()
	self.weapon:setStance(self.stances.idle)
	
	self.cooldownTimer = self.fireTime
	
	critChance = self.critChance/100.00	
	timedCrits = self.timedCrits or false
	self.threadState = coroutine.create(critfunction)
	self.critThread = coroutine.create(critFireSoundCoroutine)
	self.weapon.onLeaveAbility = function()
	  self.weapon:setStance(self.stances.idle)
	end
end

function MannFlamethrowerAttack:update(dt, fireMode, shiftHeld)
	WeaponAbility.update(self, dt, fireMode, shiftHeld)
	self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
	if timedCrits == true and  coroutine.status(self.threadState) ~= "running" then
  self:timedCritShots(critfunction)
  end

	if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy")
    and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
		self:setState(self.fire)
	end

end

function MannFlamethrowerAttack:critSoundPlayer(critCoroutine)
local status, result = coroutine.resume(self.critThread)
if not status then
error(result)
end
end

function critFireSoundCoroutine()

		if CritActive then
			if  not critsoundPlaying  and stocksoundPlaying then
			animator.stopAllSounds("fireLoop")
			animator.playSound("critfireLoop", -1)			
			end
			stocksoundPlaying = false
			critsoundPlaying = true
		else
			if critsoundPlaying  and not stocksoundPlaying then
			animator.stopAllSounds("critfireLoop")
			animator.playSound("fireLoop",-1)
			end
			stocksoundPlaying = true
			critsoundPlaying = false
		end
			coroutine.yield()			
end

function MannFlamethrowerAttack:timedCritShots(critfunction)
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

function MannFlamethrowerAttack:fire()
self.weapon:setStance(self.stances.fire)
		animator.playSound("fireStart")
		if CritActive == true then
			animator.playSound("critfireLoop",-1)
			critsoundPlaying = true
		else
			animator.playSound("fireLoop",-1)
			stocksoundPlaying = true
		end
	if self.fireMode == (self.activatingFireMode or self.abilitySlot) and status.overConsumeResource("energy", (self.energyUsage or 0) * self.dt) then
	
		while self.fireMode == (self.activatingFireMode or self.abilitySlot) and status.overConsumeResource("energy", (self.energyUsage or 0) * self.dt) do
			self:fireProjectile()
			util.wait(self.fireTime)
			if coroutine.status(self.critThread) ~= "dead" then		
					if coroutine.status(self.critThread) ~= "running"  then
					self:critSoundPlayer(critFireSoundCoroutine)
					end
				else
					self.critThread = coroutine.create(critFireSoundCoroutine)		
				end
			coroutine.yield()
		end
	
		animator.stopAllSounds("critfireLoop")
		animator.stopAllSounds("fireLoop")
	
			
	end
	self.cooldownTimer = self.fireTime
		animator.playSound("fireEnd")
	
	
	self:setState(self.cooldown)
 	self:stopSounds()
end

function MannFlamethrowerAttack:cooldown()
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
function MannFlamethrowerAttack:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
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

function MannFlamethrowerAttack:stopSounds()
  
  animator.stopAllSounds("fireStart")
  animator.stopAllSounds("fireLoop")
  animator.stopAllSounds("critfireLoop")
  animator.stopAllSounds("fireEnd")
  
end

function MannFlamethrowerAttack:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function MannFlamethrowerAttack:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function MannFlamethrowerAttack:damagePerShot()
  return (self.baseDps * self.fireTime) / self.projectileCount
end

function MannFlamethrowerAttack:energyPerShot()	
  return (status.resource("energy")/self.energyUsage)
end

function MannFlamethrowerAttack:uninit()

end
