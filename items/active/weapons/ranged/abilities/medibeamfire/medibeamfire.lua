require "/scripts/interp.lua"
require "/scripts/vec2.lua"
require "/scripts/util.lua"
MediBeamFire = WeaponAbility:new()

function MediBeamFire:init()
  self.damageConfig.baseDamage = self.baseDps * self.fireTime
  self.weapon:setStance(self.stances.idle)

  self.cooldownTimer = self.fireTime
  self.impactSoundTimer = 0

  self.weapon.onLeaveAbility = function()
--    self.weapon:setDamage()
    activeItem.setScriptedAnimationParameter("chains", {})
    animator.setParticleEmitterActive("beamCollision", false)
    animator.stopAllSounds("fireLoop")
    self.weapon:setStance(self.stances.idle)
  end
end

function MediBeamFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  self.impactSoundTimer = math.max(self.impactSoundTimer - self.dt, 0)  

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and not world.lineTileCollision(mcontroller.position(), self:firePosition())
    and self.cooldownTimer == 0 
	and not status.resourceLocked("energy") then
		self:setState(self.fire)
  end
end

function MediBeamFire:fire()
	self.weapon:setStance(self.stances.fire)
	local wasColliding = false
	local newTarget = self:findTarget()
	
	while self.fireMode == (self.activatingFireMode or self.abilitySlot) and status.overConsumeResource("energy", (self.energyUsage or 0) * self.dt) do
		newTarget = self:findTarget()		
		if newTarget then
			break						
		end				
		animator.playSound("noTarget")
		util.wait(0.5)
		coroutine.yield()		
	end
		
		animator.playSound("fireStart")
		

	while newTarget do
		
		local beamStart = self:firePosition()
				
		local beamEnd = newTarget
		local beamLength = self.beamLength
		local collidePoint = world.lineCollision(beamStart, beamEnd)				
		local newEndBeam = checkCollision(beamStart, beamEnd, beamLength, collidePoint)
		
--		self.weapon:setDamage(self.damageConfig, {self.weapon.muzzleOffset, {self.weapon.muzzleOffset[1] + beamLength, self.weapon.muzzleOffset[2]}}, self.fireTime)
		self:drawBeam(newEndBeam, collidePoint)
		self:fireProjectile()
		newTarget = self:findTarget()
		coroutine.yield()
	end
	

  self.cooldownTimer = self.fireTime
  self:reset()  
  self:setState(self.cooldown)
end


function checkCollision(beamStart, beamEnd, beamLength, collidePoint)
if collidePoint then
      beamEnd = collidePoint

      beamLength = world.magnitude(beamStart, beamEnd)

      animator.setParticleEmitterActive("beamCollision", true)
      animator.resetTransformationGroup("beamEnd")
      animator.translateTransformationGroup("beamEnd", {beamLength, 0})
    else
      animator.setParticleEmitterActive("beamCollision", false)
    end
	return beamEnd
end

function MediBeamFire:drawBeam(endPos, didCollide)
  local newChain = copy(self.chain)
  newChain.startOffset = self.weapon.muzzleOffset
  newChain.endPosition = endPos

  if didCollide then
    newChain.endSegmentImage = nil
  end

  activeItem.setScriptedAnimationParameter("chains", {newChain})
end

function MediBeamFire:cooldown()
  self.weapon:setStance(self.stances.cooldown)
  self.weapon:updateAim()

  util.wait(self.stances.cooldown.duration, function()

  end)
end

function MediBeamFire:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function MediBeamFire:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function MediBeamFire:uninit()
  self:reset()
end

function MediBeamFire:reset()
 -- self.weapon:setDamage()
activeItem.setScriptedAnimationParameter("chains", {})
  animator.setParticleEmitterActive("beamCollision", false)
  animator.stopAllSounds("fireStart")
  animator.stopAllSounds("noTarget")
end

function MediBeamFire:findTarget()--check to see if entity exists. if exist, set coords
local nearEntities = world.entityQuery(activeItem.ownerAimPosition(), 2.5, { includedTypes = {"monster","npc","player"} })
  nearEntities = util.filter(nearEntities, function(entityId)
	local position = world.entityPosition(entityId)
	local mag = world.magnitude(mcontroller.position(), position)
	
    if not contains({"friendly", "passive"}, world.entityDamageTeam(entityId).type) then
        return false
      end
	  
	if mag > self.beamLength or mag < vec2.mag(self.weapon.muzzleOffset) then	
		return false
	end

    if world.lineTileCollision(self:firePosition(), world.entityPosition(entityId)) then
      return false
    end

    return true
  end)

  if #nearEntities > 0 then
  local location = world.entityPosition(nearEntities[1])
    return location
  else
    return false
  end
end

function MediBeamFire:fireProjectile(projectileType, projectileParams, inaccuracy, projectileCount)
  local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
  params.power = 0
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.speed = util.randomInRange(params.speed)

  if not projectileType then
    projectileType = self.projectileType
  end
  if type(projectileType) == "table" then
    projectileType = projectileType[math.random(#projectileType)]
  end

  local projectileId = 0
  local spawnpoint = self:findTarget()--breaks when target is not available, 
	for i = 1, (projectileCount or self.projectileCount) do
		if params.timeToLive then
		params.timeToLive = util.randomInRange(params.timeToLive)
		end

	local projectileId  = world.spawnProjectile(
        projectileType,
        spawnpoint or self:firePosition(),
        activeItem.ownerEntityId(),
        self:aimVector(inaccuracy or self.inaccuracy),
        false,
        params
      )
	return projectileId
	end
end
