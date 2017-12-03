require "/scripts/util.lua"
require "/scripts/interp.lua"

MannFlamethrowerAttack = WeaponAbility:new()

function MannFlamethrowerAttack:init()
	self.weapon:setStance(self.stances.idle)
	
	self.cooldownTimer = self.fireTime
	
	self.weapon.onLeaveAbility = function()
	  self.weapon:setStance(self.stances.idle)
	end
end

function MannFlamethrowerAttack:update(dt, fireMode, shiftHeld)
	WeaponAbility.update(self, dt, fireMode, shiftHeld)
	self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

	if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy")
    and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
		self:setState(self.fire)
	end

end


function MannFlamethrowerAttack:fire()
self.weapon:setStance(self.stances.fire)
		animator.playSound("fireStart")

if self.fireMode == (self.activatingFireMode or self.abilitySlot) and status.overConsumeResource("energy", (self.energyUsage or 0) * self.dt) then
		animator.playSound("fireLoop",-1)
	
		while self.fireMode == (self.activatingFireMode or self.abilitySlot) and status.overConsumeResource("energy", (self.energyUsage or 0) * self.dt) do
			self:fireProjectile()
			util.wait(self.fireTime)
			coroutine.yield()
		end
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
  params.power = self:damagePerShot()
  params.powerMultiplier = 1
  params.speed = util.randomInRange(params.speed)

  if not projectileType then
    projectileType = self.projectileType
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
