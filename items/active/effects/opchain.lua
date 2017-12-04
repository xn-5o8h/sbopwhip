require "/scripts/vec2.lua"
require "/scripts/util.lua"

function update()
  localAnimator.clearDrawables()

  self.chains = animationConfig.animationParameter("chains") or {}
  for _, chain in pairs(self.chains) do
    if chain.targetEntityId then
      if world.entityExists(chain.targetEntityId) then
        chain.endPosition = world.entityPosition(chain.targetEntityId)
      end
    end
    if chain.sourcePart then
      chain.startPosition = vec2.add(entity.position(), animationConfig.partPoint(chain.sourcePart, "beamSource"))
    end
    if chain.endPart then
      chain.endPosition = vec2.add(entity.position(), animationConfig.partPoint(chain.endPart, "beamEnd"))
    end

    if not chain.targetEntityId or world.entityExists(chain.targetEntityId) then
      -- sb.logInfo("Building drawables for chain %s", chain)
      local startPosition = chain.startPosition or vec2.add(activeItemAnimation.ownerPosition(), activeItemAnimation.handPosition(chain.startOffset))
      local endPosition = chain.endPosition or vec2.add(activeItemAnimation.ownerPosition(), activeItemAnimation.handPosition(chain.endOffset))

      if chain.maxLength then
        endPosition = vec2.add(startPosition, vec2.mul(vec2.norm(world.distance(endPosition, startPosition)), chain.maxLength))
      end

      local chainVec = world.distance(endPosition, startPosition)
      local chainDirection = chainVec[1] < 0 and -1 or 1
      local chainLength = vec2.mag(chainVec)

      local arcAngle = 0
      if chain.arcRadius then
        arcAngle = chainDirection * 2 * math.asin(chainLength / (2 * chain.arcRadius))
        chainLength = chainDirection * arcAngle * chain.arcRadius
      end

      local segmentCount = math.floor(((chainLength + (chain.overdrawLength or 0)) / chain.segmentSize) + 0.5)
      if segmentCount > 0 then
        local chainStartAngle = vec2.angle(chainVec) - arcAngle / 2
        if chainVec[1] < 0 then chainStartAngle = math.pi - chainStartAngle end

        local segmentOffset = vec2.mul(vec2.norm(chainVec), chain.segmentSize)
        segmentOffset = vec2.rotate(segmentOffset, -arcAngle / 2)
        local currentBaseOffset = vec2.add(startPosition, vec2.mul(segmentOffset, 0.5))
        local lastDrawnSegment = chain.drawPercentage and math.ceil(segmentCount * chain.drawPercentage) or segmentCount
        for i = 1, lastDrawnSegment do
          local image = chain.segmentImage
          if i == 1 and chain.startSegmentImage then
            image = chain.startSegmentImage
          elseif i == lastDrawnSegment and chain.endSegmentImage then
            image = chain.endSegmentImage
          end

          -- taper applies evenly from full size at the start to (1.0 - chain.taper) size at the end
          if chain.taper then
            local taperFactor = 1 - ((i - 1) / lastDrawnSegment) * chain.taper
            image = image .. "?scale=1.0=" .. util.round(taperFactor, 1)
          end

          -- per-segment offsets (jitter, waveform, etc)
          local thisOffset = {0, 0}
          if chain.jitter then
            thisOffset = vec2.add(thisOffset, {0, (math.random() - 0.5) * chain.jitter})
          end
          if chain.waveform then
            local angle = ((i * chain.segmentSize) - (os.clock() * (chain.waveform.movement or 0))) / (chain.waveform.frequency / math.pi)
            local sineVal = math.sin(angle) * chain.waveform.amplitude * 0.5
            thisOffset = vec2.add(thisOffset, {0, sineVal})
          end

          local segmentAngle = chainStartAngle + (i - 1) * chainDirection * (arcAngle / segmentCount)

          thisOffset = vec2.rotate(thisOffset, chainVec[1] >= 0 and segmentAngle or -segmentAngle)

          local drawable = {
            image = image,
            centered = true,
            mirrored = chainVec[1] < 0,
            rotation = segmentAngle,
            position = vec2.add(currentBaseOffset, thisOffset),
            fullbright = chain.fullbright or false
          }

          localAnimator.addDrawable(drawable, chain.renderLayer)

          segmentOffset = vec2.rotate(segmentOffset, arcAngle / segmentCount)
          currentBaseOffset = vec2.add(currentBaseOffset, segmentOffset)
        end
      end
    end
  end
end
