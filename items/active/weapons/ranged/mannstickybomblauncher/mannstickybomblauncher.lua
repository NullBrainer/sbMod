require "/scripts/vec2.lua"

function init()
  self.pType = config.getParameter("projectileType")
  self.pParams = config.getParameter("projectileParameters", {})
  self.pParams.power = self.pParams.power
  self.critChance = config.getParameter("critChance")
  self.critChance = self.critChance/100.00
  self.fireOffset = config.getParameter("fireOffset")
  self.bulletCount = config.getParameter("bulletCount")
  self.maxAmmo = config.getParameter("maxAmmo", 8)
  SetGunState() 

  updateAim()

  storage.fireTimer = storage.fireTimer or 0
  self.recoilTimer = 0

  storage.activeProjectiles = storage.activeProjectiles or {}
  updateCursor()
end

function updatecritChance()
local critvalue = math.random()
CritActive = (critvalue < self.critChance)
end

function activate(fireMode, shiftHeld)
	if fireMode == "alt" and #storage.activeProjectiles > 0 then
	triggerProjectiles()
	elseif fireMode == "alt" 
	and self.bulletCount >= 0 
	and self.bulletCount < self.maxAmmo
	and storage.fireTimer <= 0 then
	reload()
	end
end

function update(dt, fireMode, shiftHeld)
  updateAim()

  storage.fireTimer = math.max(storage.fireTimer - dt, 0)
  self.recoilTimer = math.max(self.recoilTimer - dt, 0)
	if fireMode == "primary" 
	and storage.fireTimer <= 0
	and self.bulletCount == 0 then
	emptyFire()
	elseif fireMode == "primary"  
		and self.bulletCount > 0
		and storage.fireTimer <= 0
		and not world.pointTileCollision(firePosition()) then

    storage.fireTimer = config.getParameter("fireTime", 1.0)
	updatecritChance()
    fire()
  end

  activeItem.setRecoil(self.recoilTimer > 0)

  updateProjectiles()
  updateCursor()
end

function updateCursor()
  if #storage.activeProjectiles > 0 then
    activeItem.setCursor("/cursors/chargeready.cursor")
  else
    activeItem.setCursor("/cursors/reticle0.cursor")
  end
end

function uninit()
  for i, projectile in ipairs(storage.activeProjectiles) do
    world.callScriptedEntity(projectile, "setTarget", nil)
  end
end

function fire()
  
  if CritActive then
  self.pType = config.getParameter("critProjectile")
  self.pParams = config.getParameter("critprojectileParameters")
  self.pParams.powerMultiplier = 3
  else
  self.pType = config.getParameter("projectileType")
  self.pParams = config.getParameter("projectileParameters", {})
  self.pParams.powerMultiplier = 1
  end
  local projectileId = world.spawnProjectile(  
      self.pType,
      firePosition(),
      activeItem.ownerEntityId(),
      aimVector(),
      false,
      self.pParams
    )
  if projectileId then
    storage.activeProjectiles[#storage.activeProjectiles + 1] = projectileId
    triggerSingularProjectile()

  end
  if CritActive then
  animator.playSound("critfire")
  else
  animator.playSound("fire")
  end
  
  self.bulletCount = self.bulletCount - 1
  activeItem.setInstanceValue("bulletCount", self.bulletCount)	
  SetGunState()

  self.recoilTimer = config.getParameter("recoilTime", 0.12)
end

function reload()    
  self.bulletCount = self.bulletCount + 1
  activeItem.setInstanceValue("bulletCount", self.bulletCount)	
  SetGunState()
  animator.playSound("reload")
  self.recoilTimer = config.getParameter("reloadTime", 0.6)
  storage.fireTimer = config.getParameter("reloadTime", 0.5)
  end
  
function emptyFire()
animator.playSound("empty")
storage.fireTimer = config.getParameter("reloadTime", 0.5)
end

function SetGunState()
local ammo = self.bulletCount
self.bulletCount = ammo
return self.bulletCount
end

function updateAim()
  self.aimAngle, self.aimDirection = activeItem.aimAngleAndDirection(self.fireOffset[2], activeItem.ownerAimPosition())
  activeItem.setArmAngle(self.aimAngle)
  activeItem.setFacingDirection(self.aimDirection)
end

function updateProjectiles()
  local newProjectiles = {}
  for i, projectile in ipairs(storage.activeProjectiles) do
    if world.entityExists(projectile) then
      newProjectiles[#newProjectiles + 1] = projectile
    end
  end
  storage.activeProjectiles = newProjectiles
end

function triggerProjectiles()
  if #storage.activeProjectiles > 0 then
    animator.playSound("trigger")
  end
  for i, projectile in ipairs(storage.activeProjectiles) do
    world.callScriptedEntity(projectile, "trigger")
  end
end

function firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.fireOffset))
end

function aimVector()
  local aimVector = vec2.rotate({1, 0}, self.aimAngle + sb.nrand(config.getParameter("inaccuracy", 0), 0))
  aimVector[1] = aimVector[1] * self.aimDirection
  return aimVector
end

function triggerSingularProjectile()
	if #storage.activeProjectiles > 8 then		
		world.callScriptedEntity(storage.activeProjectiles[1], "trigger")	
	end
end