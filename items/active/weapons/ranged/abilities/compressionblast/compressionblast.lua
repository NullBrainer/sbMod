require "/scripts/util.lua"
require "/items/active/weapons/weapon.lua"

CompressionBlast = WeaponAbility:new()

function CompressionBlast:init()
  self:reset()

  self.cooldownTimer = 0
end

function CompressionBlast:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)

  if self.weapon.currentAbility == nil
    and self.fireMode == "alt"
    and self.cooldownTimer == 0
    and not world.lineTileCollision(mcontroller.position(), self:firePosition())
    and status.overConsumeResource("energy", self.energyUsage) then

    self:setState(self.fire)
  end
end

function CompressionBlast:fire()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()

  animator.setAnimationState("compressionBlastFire", "fire")
  animator.burstParticleEmitter("burstShotSmoke")
  animator.playSound("airblast")

  util.wait(self.stances.fire.duration, function()
    local damageArea = partDamageArea("airBlast")
    self.weapon:setDamage(self.damageConfig, damageArea)
  end)

  self.cooldownTimer = self.cooldownTime
end

function CompressionBlast:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function CompressionBlast:reset()
  animator.setAnimationState("compressionBlastFire", "idle")
end

function CompressionBlast:uninit()
  self:reset()
end
