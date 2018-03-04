require "/items/active/weapons/weapon.lua"
require "/scripts/vec2.lua"

MannZoom = WeaponAbility:new()


function MannZoom:init()
  self:reset()
  self.cooldownTimer = 0
  self.zoomTime = 0
  self.CritActive = false
end

function MannZoom:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
  
  if self.weapon.currentAbility == nil
     and self.fireMode == "alt"
     and self.cooldownTimer == 0
     and status.overConsumeResource("energy", self:energyPerShot()) then	 
    self:setState(self.zoomedin)	
  end
  
  if status.resourcePositive("energy") and not status.resourceLocked("energy") then
  status.setResource("energyRegenBlock", 1.0)
  end
end

function MannZoom:zoomedin()
  self.weapon:setStance(self.stances.zoomedin)
  
  self.weapon:updateAim() 
  self.charged = false;
  self.zoomTime = 0
    while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
		if self.walkWhileFiring then mcontroller.controlModifiers({runningSuppressed = true}) end

		self.zoomTime = self.zoomTime + self.dt
		if self:isCharged() and not self.charged then
			animator.playSound("charged")
			self.charged = true
			self.CritActive = self.charged
		end	
		
		coroutine.yield()
	end
	
  self:setState(self.fire)
end

function MannZoom:fire()

  self.weapon:setStance(self.stances.fire)
  
  self.weapon:updateAim() 
  if self.CritActive then
	animator.playSound("critfire")
  else
    animator.playSound("fire")
  end
  
  if self.stances.fire.duration then
	util.wait(self.stances.fire.duration)
  end
    
  self:muzzleFlash()		
  self:fireProjectile() 
  self:reset()  
  self.cooldownTimer = self.fireTime
  self:setState(self.cooldown)
end


function MannZoom:cooldown()
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

function MannZoom:muzzleFlash()

end

function MannZoom:isCharged()
	return self.zoomTime >= self.maxcritTime
end

function MannZoom:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.fireOffset))
end

function MannZoom:aimVector()
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + self.weapon.relativeArmRotation )
  aimVector[1] = aimVector[1] * self.weapon.aimDirection
  return aimVector
end

function MannZoom:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
  local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
  if self.CritActive then
	params = sb.jsonMerge(self.critprojectileParameters)
	params.powerMultiplier = 3
  else
    params.powerMultiplier = 1
  end
    params.power = self:damagePerShot()
  params.speed = util.randomInRange(params.speed)

  if not projectileType then
	if self.CritActive then
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
      params.timeToLive = util.randomInRange(prams.timeToLive)
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
   self.CritActive = false
  return projectileId
end

function MannZoom:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
  animator.setAnimationState("firing", "fire")
  animator.burstParticleEmitter("muzzleFlash")
  animator.setLightActive("muzzleFlash", true)
end

function MannZoom:damagePerShot()
  return (self.baseDamage or (self.baseDps * self.fireTime)) / self.projectileCount
end

function MannZoom:energyPerShot()
  return status.resourceMax("energy")/self.shotsperreload
end

function MannZoom:reset()
	self.weapon:setStance(self.stances.idle)
end

function MannZoom:uninit()
  self:reset()
end

--3.3 seconds to fully charge
--critical hit if zoomedin > 3.3 seconds
--critical dmg: min is 150 maximum is 450
--basedmg:50 to 150 if zoomedin under 3.3 seconds
--