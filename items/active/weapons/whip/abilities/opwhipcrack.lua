require "/scripts/util.lua"
require "/items/active/weapons/weapon.lua"

-- whip primary attack
WhipCrack = WeaponAbility:new()

function WhipCrack:init()
  self.damageConfig.baseDamage = self.chainDps * self.fireTime

  self.weapon:setStance(self.stances.idle)
  animator.setAnimationState("attack", "idle")
  activeItem.setScriptedAnimationParameter("chains", nil)

  self.cooldownTimer = self:cooldownTime()

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end

  self.projectileConfig = self.projectileConfig or {}

  self.chain = config.getParameter("chain")
end

-- Ticks on every update regardless if this is the active ability
function WhipCrack:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if self.fireMode == "primary" and self:canStartAttack() then
    self:setState(self.windup)
  end
end

function WhipCrack:canStartAttack()
  return not self.weapon.currentAbility and self.cooldownTimer == 0
end

-- State: windup
function WhipCrack:windup()
  self.weapon:setStance(self.stances.windup)

  animator.setAnimationState("attack", "windup")

  util.wait(self.stances.windup.duration)

  self:setState(self.extend)
end

-- State: extend
function WhipCrack:extend()
  self.weapon:setStance(self.stances.extend)

  animator.setAnimationState("attack", "extend")
  animator.playSound("swing")

  util.wait(self.stances.extend.duration)

  animator.setAnimationState("attack", "fire")
  self:setState(self.fire)
end

-- State: fire

function WhipCrack:interact(id)
  sb.logInfo("%s %s %s", id, world.entityType(id), world.entityName(id))
  if world.entityType(id) == "object" then
    local itemConfig = root.itemConfig(world.entityName(id)).config
    if itemConfig then
      --sb.logInfo(sb.printJson(itemConfig, 1))
      if itemConfig.interactAction then
        activeItem.interact(itemConfig.interactAction, activeItem.ownerEntityId(), itemConfig.interactData)
      end
      if itemConfig.category == "door" then
          world.sendEntityMessage(id, "openDoor")
      end
      if itemConfig.category == "storage" then
          world.containerOpen(id)
          --activeItem.interact("openChestInterface", activeItem.ownerEntityId(), itemConfig.uiConfig:gsub("<slots>", itemConfig.slotCount))
      end
    end
  end
end

function WhipCrack:fire()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()

  local chainStartPos = vec2.add(mcontroller.position(), activeItem.handPosition(self.chain.startOffset))
  local chainLength = world.magnitude(chainStartPos, activeItem.ownerAimPosition())
  chainLength = math.min(self.chain.length[2], math.max(self.chain.length[1], chainLength))

  self.chain.endOffset = vec2.add(self.chain.startOffset, {chainLength, 0})
  
  self.chain.endOffset = vec2.add(self.chain.startOffset, {chainLength, 0})

  local chainEndPos = vec2.add(mcontroller.position(), activeItem.handPosition(self.chain.endOffset))

  activeItem.setScriptedAnimationParameter("chains", {self.chain})

  animator.resetTransformationGroup("endpoint")
  animator.translateTransformationGroup("endpoint", self.chain.endOffset)
  animator.burstParticleEmitter("crack")
  animator.playSound("crack")

  self.projectileConfig.power = self:crackDamage()
  self.projectileConfig.powerMultiplier = activeItem.ownerPowerMultiplier()

  local projectileAngle = vec2.withAngle(self.weapon.aimAngle)
  if self.weapon.aimDirection < 0 then projectileAngle[1] = -projectileAngle[1] end

  local objectAt = world.objectAt(activeItem.ownerAimPosition())
  if objectAt then WhipCrack:interact(objectAt) else
    local entitiesAtTarget = world.entityQuery(activeItem.ownerAimPosition(), 0.1)
    for _,id in ipairs(entitiesAtTarget) do
      WhipCrack:interact(id)
    end
  end

  world.spawnProjectile(
    self.projectileType,
    chainEndPos,
    activeItem.ownerEntityId(),
    projectileAngle,
    false,
    self.projectileConfig
  )

  util.wait(self.stances.fire.duration, function()
    if self.damageConfig.baseDamage > 0 then
      self.weapon:setDamage(self.damageConfig, {self.chain.startOffset, {self.chain.endOffset[1] + 0.75, self.chain.endOffset[2]}}, self.fireTime)
    end
  end)

  animator.setAnimationState("attack", "idle")
  activeItem.setScriptedAnimationParameter("chains", nil)

  self.cooldownTimer = self:cooldownTime()
end

function WhipCrack:cooldownTime()
  return self.fireTime - (self.stances.windup.duration + self.stances.extend.duration + self.stances.fire.duration)
end

function WhipCrack:uninit(unloaded)
  self.weapon:setDamage()
  activeItem.setScriptedAnimationParameter("chains", nil)
end

function WhipCrack:chainDamage()
  return (self.chainDps * self.fireTime) * config.getParameter("damageLevelMultiplier")
end

function WhipCrack:crackDamage()
  return (self.crackDps * self.fireTime) * config.getParameter("damageLevelMultiplier")
end
