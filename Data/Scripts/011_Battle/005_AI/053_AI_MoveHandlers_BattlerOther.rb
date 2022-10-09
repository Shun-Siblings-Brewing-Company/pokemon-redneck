#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("SleepTarget",
  proc { |move, user, target, ai, battle|
    next true if move.statusMove? && !target.battler.pbCanSleep?(user.battler, false, move.move)
  }
)
Battle::AI::Handlers::MoveEffectScore.add("SleepTarget",
  proc { |score, move, user, target, ai, battle|
    next score if target.effects[PBEffects::Yawn] > 0   # Target is going to fall asleep anyway
    # No score modifier if the sleep will be removed immediately
    next score if target.has_active_item?([:CHESTOBERRY, :LUMBERRY])
    next score if target.faster_than?(user) &&
                  target.has_active_ability?(:HYDRATION) &&
                  [:Rain, :HeavyRain].include?(target.battler.effectiveWeather)
    if target.battler.pbCanSleep?(user.battler, false, move.move)
      case move.additional_effect_usability(user, target)
      when 1   # Additional effect will be negated
        next score
      when 3   # Additional effect has an increased chance to work
        score += 5
      end
      # Inherent preference
      score += 15
      # Prefer if the user or an ally has a move/ability that is better if the target is asleep
      ai.each_same_side_battler(user.side) do |b|
        score += 5 if b.check_for_move { |m| ["DoublePowerIfTargetAsleepCureTarget",
                                              "DoublePowerIfTargetStatusProblem",
                                              "HealUserByHalfOfDamageDoneIfTargetAsleep",
                                              "StartDamageTargetEachTurnIfTargetAsleep"].include?(m.function) }
        score += 10 if b.has_active_ability?(:BADDREAMS)
      end
      # Don't prefer if target benefits from having the sleep status problem
      # NOTE: The target's Guts/Quick Feet will benefit from the target being
      #       asleep, but the target won't (usually) be able to make use of
      #       them, so they're not worth considering.
      score -= 10 if target.has_active_ability?(:EARLYBIRD)
      score -= 5 if target.has_active_ability?(:MARVELSCALE)
      # Don't prefer if target has a move it can use while asleep
      score -= 8 if target.check_for_move { |m| m.usableWhenAsleep? }
      # Don't prefer if the target can heal itself (or be healed by an ally)
      if target.has_active_ability?(:SHEDSKIN)
        score -= 5
      elsif target.has_active_ability?(:HYDRATION) &&
            [:Rain, :HeavyRain].include?(target.battler.effectiveWeather)
        score -= 10
      end
      ai.each_same_side_battler(target.side) do |b|
        score -= 5 if b.index != target.index && b.has_active_ability?(:HEALER)
      end
    end
    next score
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("SleepTargetIfUserDarkrai",
  proc { |move, user, target, ai, battle|
    next true if !user.battler.isSpecies?(:DARKRAI) && user.effects[PBEffects::TransformSpecies] != :DARKRAI
    next true if move.statusMove? && !target.battler.pbCanSleep?(user.battler, false, move.move)
  }
)
Battle::AI::Handlers::MoveEffectScore.copy("SleepTarget",
                                           "SleepTargetIfUserDarkrai")

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.copy("SleepTarget",
                                           "SleepTargetChangeUserMeloettaForm")

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("SleepTargetNextTurn",
  proc { |move, user, target, ai, battle|
    next true if target.effects[PBEffects::Yawn] > 0
    next true if !target.battler.pbCanSleep?(user.battler, false, move.move)
  }
)
Battle::AI::Handlers::MoveEffectScore.copy("SleepTarget",
                                           "SleepTargetNextTurn")

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("PoisonTarget",
  proc { |move, user, target, ai, battle|
    next true if move.statusMove? && !target.battler.pbCanPoison?(user.battler, false, move.move)
  }
)
Battle::AI::Handlers::MoveEffectScore.add("PoisonTarget",
  proc { |score, move, user, target, ai, battle|
    next score if target.effects[PBEffects::Yawn] > 0   # Target is going to fall asleep
    next score - 40 if move.statusMove? && target.has_active_ability?(:POISONHEAL)
    # No score modifier if the poisoning will be removed immediately
    next score if target.has_active_item?([:PECHABERRY, :LUMBERRY])
    next score if target.faster_than?(user) &&
                  target.has_active_ability?(:HYDRATION) &&
                  [:Rain, :HeavyRain].include?(target.battler.effectiveWeather)
    if target.battler.pbCanPoison?(user.battler, false, move.move)
      case move.additional_effect_usability(user, target)
      when 1   # Additional effect will be negated
        next score
      when 3   # Additional effect has an increased chance to work
        score += 5
      end
      # Inherent preference
      score += 10
      # Prefer if the target is at high HP
      score += 10 * target.hp / target.totalhp
      # Prefer if the user or an ally has a move/ability that is better if the target is poisoned
      ai.each_same_side_battler(user.side) do |b|
        score += 5 if b.check_for_move { |m| ["DoublePowerIfTargetPoisoned",
                                              "DoublePowerIfTargetStatusProblem"].include?(m.function) }
        score += 10 if b.has_active_ability?(:MERCILESS)
      end
      # Don't prefer if target benefits from having the poison status problem
      score -= 8 if target.has_active_ability?([:GUTS, :MARVELSCALE, :QUICKFEET, :TOXICBOOST])
      score -= 25 if target.has_active_ability?(:POISONHEAL)
      score -= 15 if target.has_active_ability?(:SYNCHRONIZE) &&
                     user.battler.pbCanPoisonSynchronize?(target.battler)
      score -= 5 if target.check_for_move { |m| ["DoublePowerIfUserPoisonedBurnedParalyzed",
                                                 "CureUserBurnPoisonParalysis"].include?(m.function) }
      score -= 10 if target.check_for_move { |m|
        m.function == "GiveUserStatusToTarget" && user.battler.pbCanPoison?(target.battler, false, m)
      }
      # Don't prefer if the target won't take damage from the poison
      score -= 15 if !target.battler.takesIndirectDamage?
      # Don't prefer if the target can heal itself (or be healed by an ally)
      if target.has_active_ability?(:SHEDSKIN)
        score -= 5
      elsif target.has_active_ability?(:HYDRATION) &&
            [:Rain, :HeavyRain].include?(target.battler.effectiveWeather)
        score -= 10
      end
      ai.each_same_side_battler(target.side) do |b|
        score -= 5 if b.index != target.index && b.has_active_ability?(:HEALER)
      end
    end
    next score
  }
)

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("PoisonTargetLowerTargetSpeed1",
  proc { |move, user, target, ai, battle|
    next true if !target.battler.pbCanPoison?(user.battler, false, move.move) &&
                 !target.battler.pbCanLowerStatStage?(:SPEED, user.battler, move.move)
  }
)
Battle::AI::Handlers::MoveEffectScore.add("PoisonTargetLowerTargetSpeed1",
  proc { |score, move, user, target, ai, battle|
    score = Battle::AI::Handlers.apply_move_effect_score("PoisonTarget",
       score, move, user, target, ai, battle)
    score = Battle::AI::Handlers.apply_move_effect_score("LowerTargetSpeed1",
       score, move, user, target, ai, battle)
    next score
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.copy("PoisonTarget",
                                            "BadPoisonTarget")
Battle::AI::Handlers::MoveEffectScore.copy("PoisonTarget",
                                           "BadPoisonTarget")

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("ParalyzeTarget",
  proc { |move, user, target, ai, battle|
    next true if move.statusMove? && !target.battler.pbCanParalyze?(user.battler, false, move.move)
  }
)
Battle::AI::Handlers::MoveEffectScore.add("ParalyzeTarget",
  proc { |score, move, user, target, ai, battle|
    next score if target.effects[PBEffects::Yawn] > 0   # Target is going to fall asleep
    # No score modifier if the paralysis will be removed immediately
    next score if target.has_active_item?([:CHERIBERRY, :LUMBERRY])
    next score if target.faster_than?(user) &&
                  target.has_active_ability?(:HYDRATION) &&
                  [:Rain, :HeavyRain].include?(target.battler.effectiveWeather)
    if target.battler.pbCanParalyze?(user.battler, false, move.move)
      case move.additional_effect_usability(user, target)
      when 1   # Additional effect will be negated
        next score
      when 3   # Additional effect has an increased chance to work
        score += 5
      end
      # Inherent preference (because of the chance of full paralysis)
      score += 10
      # Prefer if the target is faster than the user but will become slower if
      # paralysed
      if target.faster_than?(user)
        user_speed = user.rough_stat(:SPEED)
        target_speed = target.rough_stat(:SPEED)
        score += 10 if target_speed < user_speed * ((Settings::MECHANICS_GENERATION >= 7) ? 2 : 4)
      end
      # Prefer if the target is confused or infatuated, to compound the turn skipping
      score += 5 if target.effects[PBEffects::Confusion] > 1
      score += 5 if target.effects[PBEffects::Attract] >= 0
      # Prefer if the user or an ally has a move/ability that is better if the target is paralysed
      ai.each_same_side_battler(user.side) do |b|
        score += 5 if b.check_for_move { |m| ["DoublePowerIfTargetParalyzedCureTarget",
                                              "DoublePowerIfTargetStatusProblem"].include?(m.function) }
      end
      # Don't prefer if target benefits from having the paralysis status problem
      score -= 8 if target.has_active_ability?([:GUTS, :MARVELSCALE, :QUICKFEET])
      score -= 15 if target.has_active_ability?(:SYNCHRONIZE) &&
                     user.battler.pbCanParalyzeSynchronize?(target.battler)
      score -= 5 if target.check_for_move { |m| ["DoublePowerIfUserPoisonedBurnedParalyzed",
                                                 "CureUserBurnPoisonParalysis"].include?(m.function) }
      score -= 10 if target.check_for_move { |m|
        m.function == "GiveUserStatusToTarget" && user.battler.pbCanParalyze?(target.battler, false, m)
      }
      # Don't prefer if the target can heal itself (or be healed by an ally)
      if target.has_active_ability?(:SHEDSKIN)
        score -= 5
      elsif target.has_active_ability?(:HYDRATION) &&
            [:Rain, :HeavyRain].include?(target.battler.effectiveWeather)
        score -= 10
      end
      ai.each_same_side_battler(target.side) do |b|
        score -= 5 if b.index != target.index && b.has_active_ability?(:HEALER)
      end
    end
    next score
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("ParalyzeTargetIfNotTypeImmune",
  proc { |move, user, target, ai, battle|
    eff = target.effectiveness_of_type_against_battler(move.rough_type, user)
    next true if Effectiveness.ineffective?(eff)
    next true if move.statusMove? && !target.battler.pbCanParalyze?(user.battler, false, move.move)
  }
)
Battle::AI::Handlers::MoveEffectScore.copy("ParalyzeTarget",
                                           "ParalyzeTargetIfNotTypeImmune")

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.copy("ParalyzeTarget",
                                           "ParalyzeTargetAlwaysHitsInRainHitsTargetInSky")

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("ParalyzeFlinchTarget",
  proc { |score, move, user, target, ai, battle|
    score = Battle::AI::Handlers.apply_move_effect_score("ParalyzeTarget",
       score, move, user, target, ai, battle)
    score = Battle::AI::Handlers.apply_move_effect_score("FlinchTarget",
       score, move, user, target, ai, battle)
    next score
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("BurnTarget",
  proc { |move, user, target, ai, battle|
    next true if move.statusMove? && !target.battler.pbCanBurn?(user.battler, false, move.move)
  }
)
Battle::AI::Handlers::MoveEffectScore.add("BurnTarget",
  proc { |score, move, user, target, ai, battle|
    next score if target.effects[PBEffects::Yawn] > 0   # Target is going to fall asleep
    # No score modifier if the burn will be removed immediately
    next score if target.has_active_item?([:RAWSTBERRY, :LUMBERRY])
    next score if target.faster_than?(user) &&
                  target.has_active_ability?(:HYDRATION) &&
                  [:Rain, :HeavyRain].include?(target.battler.effectiveWeather)
    if target.battler.pbCanBurn?(user.battler, false, move.move)
      case move.additional_effect_usability(user, target)
      when 1   # Additional effect will be negated
        next score
      when 3   # Additional effect has an increased chance to work
        score += 5
      end
      # Inherent preference
      score += 10
      # Prefer if the target knows any physical moves that will be weaked by a burn
      if !target.has_active_ability?(:GUTS) && target.check_for_move { |m| m.physicalMove? }
        score += 5
        score += 8 if !target.check_for_move { |m| m.specialMove? }
      end
      # Prefer if the user or an ally has a move/ability that is better if the target is burned
      ai.each_same_side_battler(user.side) do |b|
        score += 5 if b.check_for_move { |m| m.function == "DoublePowerIfTargetStatusProblem" }
      end
      # Don't prefer if target benefits from having the burn status problem
      score -= 8 if target.has_active_ability?([:FLAREBOOST, :GUTS, :MARVELSCALE, :QUICKFEET])
      score -= 5 if target.has_active_ability?(:HEATPROOF)
      score -= 15 if target.has_active_ability?(:SYNCHRONIZE) &&
                     user.battler.pbCanBurnSynchronize?(target.battler)
      score -= 5 if target.check_for_move { |m| ["DoublePowerIfUserPoisonedBurnedParalyzed",
                                                 "CureUserBurnPoisonParalysis"].include?(m.function) }
      score -= 10 if target.check_for_move { |m|
        m.function == "GiveUserStatusToTarget" && user.battler.pbCanBurn?(target.battler, false, m)
      }
      # Don't prefer if the target won't take damage from the burn
      score -= 15 if !target.battler.takesIndirectDamage?
      # Don't prefer if the target can heal itself (or be healed by an ally)
      if target.has_active_ability?(:SHEDSKIN)
        score -= 5
      elsif target.has_active_ability?(:HYDRATION) &&
            [:Rain, :HeavyRain].include?(target.battler.effectiveWeather)
        score -= 10
      end
      ai.each_same_side_battler(target.side) do |b|
        score -= 5 if b.index != target.index && b.has_active_ability?(:HEALER)
      end
    end
    next score
  }
)

#===============================================================================
#
#===============================================================================
# BurnTargetIfTargetStatsRaisedThisTurn

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("BurnFlinchTarget",
  proc { |score, move, user, target, ai, battle|
    score = Battle::AI::Handlers.apply_move_effect_score("BurnTarget",
       score, move, user, target, ai, battle)
    score = Battle::AI::Handlers.apply_move_effect_score("FlinchTarget",
       score, move, user, target, ai, battle)
    next score
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("FreezeTarget",
  proc { |move, user, target, ai, battle|
    next true if move.statusMove? && !target.battler.pbCanFreeze?(user.battler, false, move.move)
  }
)
Battle::AI::Handlers::MoveEffectScore.add("FreezeTarget",
  proc { |score, move, user, target, ai, battle|
    next score if target.effects[PBEffects::Yawn] > 0   # Target is going to fall asleep
    # No score modifier if the freeze will be removed immediately
    next score if target.has_active_item?([:ASPEARBERRY, :LUMBERRY])
    next score if target.faster_than?(user) &&
                  target.has_active_ability?(:HYDRATION) &&
                  [:Rain, :HeavyRain].include?(target.battler.effectiveWeather)
    if target.battler.pbCanFreeze?(user.battler, false, move.move)
      case move.additional_effect_usability(user, target)
      when 1   # Additional effect will be negated
        next score
      when 3   # Additional effect has an increased chance to work
        score += 5
      end
      # Inherent preference
      score += 15
      # Prefer if the user or an ally has a move/ability that is better if the target is frozen
      ai.each_same_side_battler(user.side) do |b|
        score += 5 if b.check_for_move { |m| m.function == "DoublePowerIfTargetStatusProblem" }
      end
      # Don't prefer if target benefits from having the frozen status problem
      # NOTE: The target's Guts/Quick Feet will benefit from the target being
      #       frozen, but the target won't be able to make use of them, so
      #       they're not worth considering.
      score -= 5 if target.has_active_ability?(:MARVELSCALE)
      # Don't prefer if the target knows a move that can thaw it
      score -= 15 if target.check_for_move { |m| m.thawsUser? }
      # Don't prefer if the target can heal itself (or be healed by an ally)
      if target.has_active_ability?(:SHEDSKIN)
        score -= 5
      elsif target.has_active_ability?(:HYDRATION) &&
            [:Rain, :HeavyRain].include?(target.battler.effectiveWeather)
        score -= 10
      end
      ai.each_same_side_battler(target.side) do |b|
        score -= 5 if b.index != target.index && b.has_active_ability?(:HEALER)
      end
    end
    next score
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.copy("FreezeTarget",
                                           "FreezeTargetSuperEffectiveAgainstWater")

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.copy("FreezeTarget",
                                           "FreezeTargetAlwaysHitsInHail")

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("FreezeTarget",
  proc { |score, move, user, target, ai, battle|
    score = Battle::AI::Handlers.apply_move_effect_score("FreezeTarget",
       score, move, user, target, ai, battle)
    score = Battle::AI::Handlers.apply_move_effect_score("FlinchTarget",
       score, move, user, target, ai, battle)
    next score
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("ParalyzeBurnOrFreezeTarget",
  proc { |score, move, user, target, ai, battle|
    next score if target.effects[PBEffects::Yawn] > 0   # Target is going to fall asleep
    # No score modifier if the status problem will be removed immediately
    next score if target.has_active_item?(:LUMBERRY)
    next score if target.faster_than?(user) &&
                  target.has_active_ability?(:HYDRATION) &&
                  [:Rain, :HeavyRain].include?(target.battler.effectiveWeather)
    # Scores for the possible effects
    score += (Battle::AI::Handlers.apply_move_effect_score("ParalyzeTarget",
       100, move, user, target, ai, battle) - 100) / 3
    score += (Battle::AI::Handlers.apply_move_effect_score("BurnTarget",
       100, move, user, target, ai, battle) - 100) / 3
    score += (Battle::AI::Handlers.apply_move_effect_score("FreezeTarget",
       100, move, user, target, ai, battle) - 100) / 3
    next score
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("GiveUserStatusToTarget",
  proc { |move, user, target, ai, battle|
    next true if user.status == :NONE
    next true if !target.battler.pbCanInflictStatus?(user.status, user.battler, false, move.move)
  }
)
Battle::AI::Handlers::MoveEffectScore.add("GiveUserStatusToTarget",
  proc { |score, move, user, target, ai, battle|
    score += 10   # For getting rid of the user's status problem
    case user.status
    when :SLEEP
      next Battle::AI::Handlers.apply_move_effect_score("SleepTarget",
         score, move, user, target, ai, battle)
    when :PARALYSIS
      next Battle::AI::Handlers.apply_move_effect_score("ParalyzeTarget",
         score, move, user, target, ai, battle)
    when :POISON
      next Battle::AI::Handlers.apply_move_effect_score("PoisonTarget",
         score, move, user, target, ai, battle)
    when :BURN
      next Battle::AI::Handlers.apply_move_effect_score("BurnTarget",
         score, move, user, target, ai, battle)
    when :FROZEN
      next Battle::AI::Handlers.apply_move_effect_score("FreezeTarget",
         score, move, user, target, ai, battle)
    end
    next score
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("CureUserBurnPoisonParalysis",
  proc { |move, user, target, ai, battle|
    next true if ![:BURN, :POISON, :PARALYSIS].include?(user.status)
  }
)
Battle::AI::Handlers::MoveEffectScore.add("CureUserBurnPoisonParalysis",
  proc { |score, move, user, target, ai, battle|
    next score + 15
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("CureUserPartyStatus",
  proc { |move, user, target, ai, battle|
    has_effect = battle.allSameSideBattlers(user.battler).any? { |b| b.status != :NONE }
    if !has_effect
      has_effect = battle.pbParty(user.index).any? { |pkmn| pkmn&.able? && pkmn.status != :NONE }
    end
    next !has_effect
  }
)
Battle::AI::Handlers::MoveEffectScore.add("CureUserPartyStatus",
  proc { |score, move, user, target, ai, battle|
    battle.pbParty(user.index).each do |pkmn|
      score += 10 if pkmn && pkmn.status != :NONE
    end
    next score
  }
)

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("CureTargetBurn",
  proc { |score, move, user, target, ai, battle|
    if target.status == :BURN
      if target.opposes?(user)
        score -= 40
      else
        score += 40
      end
    end
    next score
  }
)

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("StartUserSideImmunityToInflictedStatus",
  proc { |move, user, target, ai, battle|
    next true if user.pbOwnSide.effects[PBEffects::Safeguard] > 0
  }
)
Battle::AI::Handlers::MoveEffectScore.add("StartUserSideImmunityToInflictedStatus",
  proc { |score, move, user, target, ai, battle|
    if user.status != :NONE
      score -= 20
    else
      score += 10
    end
    next score
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("FlinchTarget",
  proc { |score, move, user, target, ai, battle|
    next score if target.faster_than?(user) || target.effects[PBEffects::Substitute] > 0
    next score if target.has_active_ability?(:INNERFOCUS) && !battle.moldBreaker
    case move.additional_effect_usability(user, target)
    when 1   # Additional effect will be negated
      next score
    when 3   # Additional effect has an increased chance to work
      score += 5
    end
    # Inherent preference
    score += 10
    # Prefer if the target is paralysed, confused or infatuated, to compound the turn skipping
    # TODO: Also prefer if the target is trapped in battle or can't switch out?
    score += 5 if target.status == :PARALYSIS ||
                  target.effects[PBEffects::Confusion] > 1 ||
                  target.effects[PBEffects::Attract] >= 0
    next score
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("FlinchTargetFailsIfUserNotAsleep",
  proc { |move, user, target, ai, battle|
    next true if !user.battler.asleep?
  }
)
Battle::AI::Handlers::MoveEffectScore.copy("FlinchTarget",
                                           "FlinchTargetFailsIfUserNotAsleep")

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("FlinchTargetFailsIfNotUserFirstTurn",
  proc { |move, user, target, ai, battle|
    next true if user.turnCount > 0
  }
)
Battle::AI::Handlers::MoveEffectScore.copy("FlinchTarget",
                                           "FlinchTargetFailsIfNotUserFirstTurn")

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveBasePower.add("FlinchTargetDoublePowerIfTargetInSky",
  proc { |power, move, user, target, ai, battle|
    next move.move.pbBaseDamage(power, user.battler, target.battler)
  }
)
Battle::AI::Handlers::MoveEffectScore.copy("FlinchTarget",
                                           "FlinchTargetDoublePowerIfTargetInSky")

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("ConfuseTarget",
  proc { |move, user, target, ai, battle|
    next true if move.statusMove? && !target.battler.pbCanConfuse?(user.battler, false, move.move)
  }
)
Battle::AI::Handlers::MoveEffectScore.add("ConfuseTarget",
  proc { |score, move, user, target, ai, battle|
    # No score modifier if the status problem will be removed immediately
    next score if target.has_active_item?(:PERSIMBERRY)
    if target.battler.pbCanConfuse?(user.battler, false, move.move)
      case move.additional_effect_usability(user, target)
      when 1   # Additional effect will be negated
        next score
      when 3   # Additional effect has an increased chance to work
        score += 5
      end
      # Inherent preference
      score += 5
      # Prefer if the target is at high HP
      score += 10 * target.hp / target.totalhp
      # Prefer if the target is paralysed or infatuated, to compound the turn skipping
      # TODO: Also prefer if the target is trapped in battle or can't switch out?
      score += 5 if target.status == :PARALYSIS || target.effects[PBEffects::Attract] >= 0
      # Don't prefer if target benefits from being confused
      score -= 10 if target.has_active_ability?(:TANGLEDFEET)
    end
    next score
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.copy("ConfuseTarget",
                                           "ConfuseTargetAlwaysHitsInRainHitsTargetInSky")

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("AttractTarget",
  proc { |move, user, target, ai, battle|
    next true if move.statusMove? && !target.battler.pbCanAttract?(user.battler, false)
  }
)
Battle::AI::Handlers::MoveEffectScore.add("AttractTarget",
  proc { |score, move, user, target, ai, battle|
    if target.battler.pbCanAttract?(user.battler, false)
      case move.additional_effect_usability(user, target)
      when 1   # Additional effect will be negated
        next score
      when 3   # Additional effect has an increased chance to work
        score += 5
      end
      # Inherent preference
      score += 10
      # Prefer if the target is paralysed or confused, to compound the turn skipping
      # TODO: Also prefer if the target is trapped in battle or can't switch out?
      score += 5 if target.status == :PARALYSIS || target.effects[PBEffects::Confusion] > 1
      # Don't prefer if the target can infatuate the user because of this move
      score -= 10 if target.has_active_item?(:DESTINYKNOT) &&
                     user.battler.pbCanAttract?(target.battler, false)
      # Don't prefer if the user has another way to infatuate the target
      score -= 8 if move.statusMove? && user.has_active_ability?(:CUTECHARM)
    end
    next score
  }
)

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("SetUserTypesBasedOnEnvironment",
  proc { |move, user, target, ai, battle|
    next true if !user.battler.canChangeType?
    new_type = nil
    terr_types = Battle::Move::SetUserTypesBasedOnEnvironment::TERRAIN_TYPES
    terr_type = terr_types[battle.field.terrain]
    if terr_type && GameData::Type.exists?(terr_type)
      new_type = terr_type
    else
      env_types = Battle::Move::SetUserTypesBasedOnEnvironment::ENVIRONMENT_TYPES
      new_type = env_types[battle.environment] || :NORMAL
      new_type = :NORMAL if !GameData::Type.exists?(new_type)
    end
    next true if !GameData::Type.exists?(new_type) || !user.battler.pbHasOtherType?(new_type)
  }
)

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("SetUserTypesToResistLastAttack",
  proc { |move, user, target, ai, battle|
    next true if !user.battler.canChangeType?
    next true if !target.battler.lastMoveUsed || !target.battler.lastMoveUsedType ||
                 GameData::Type.get(target.battler.lastMoveUsedType).pseudo_type
    has_possible_type = false
    GameData::Type.each do |t|
      next if t.pseudo_type || user.has_type?(t.id) ||
              !Effectiveness.resistant_type?(target.battler.lastMoveUsedType, t.id)
      has_possible_type = true
      break
    end
    next !has_possible_type
  }
)

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("SetUserTypesToTargetTypes",
  proc { |move, user, target, ai, battle|
    next true if !user.battler.canChangeType?
    next true if target.battler.pbTypes(true).empty?
    next true if user.battler.pbTypes == target.battler.pbTypes &&
                 user.effects[PBEffects::Type3] == target.effects[PBEffects::Type3]
  }
)

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("SetUserTypesToUserMoveType",
  proc { |move, user, target, ai, battle|
    next true if !user.battler.canChangeType?
    has_possible_type = false
    user.battler.eachMoveWithIndex do |m, i|
      break if Settings::MECHANICS_GENERATION >= 6 && i > 0
      next if GameData::Type.get(m.type).pseudo_type
      next if user.has_type?(m.type)
      has_possible_type = true
      break
    end
    next !has_possible_type
  }
)

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("SetTargetTypesToPsychic",
  proc { |move, user, target, ai, battle|
    next move.move.pbFailsAgainstTarget?(user.battler, target.battler, false)
  }
)

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.copy("SetTargetTypesToPsychic",
                                            "SetTargetTypesToWater")

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.copy("SetTargetTypesToWater",
                                            "AddGhostTypeToTarget")

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.copy("AddGhostTypeToTarget",
                                            "AddGrassTypeToTarget")

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("UserLosesFireType",
  proc { |move, user, target, ai, battle|
    next true if !user.has_type?(:FIRE)
  }
)

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("SetTargetAbilityToSimple",
  proc { |move, user, target, ai, battle|
    next true if !GameData::Ability.exists?(:SIMPLE)
    next true if target.battler.unstoppableAbility? ||
                 [:TRUANT, :SIMPLE].include?(target.ability_id)
  }
)

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("SetTargetAbilityToInsomnia",
  proc { |move, user, target, ai, battle|
    next true if !GameData::Ability.exists?(:INSOMNIA)
    next true if target.battler.unstoppableAbility? ||
                 [:TRUANT, :INSOMNIA].include?(target.ability_id)
  }
)

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("SetUserAbilityToTargetAbility",
  proc { |move, user, target, ai, battle|
    next true if user.battler.unstoppableAbility?
    next true if !target.ability || user.ability_id == target.ability_id
    next true if target.battler.ungainableAbility? ||
                 [:POWEROFALCHEMY, :RECEIVER, :TRACE, :WONDERGUARD].include?(target.ability_id)
  }
)
Battle::AI::Handlers::MoveEffectScore.add("SetUserAbilityToTargetAbility",
  proc { |score, move, user, target, ai, battle|
    score -= 40   # don't prefer this move
    if ai.trainer.medium_skill? && user.opposes?(target)
      score -= 50 if [:TRUANT, :SLOWSTART].include?(target.ability_id)
    end
    next score
  }
)

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("SetTargetAbilityToUserAbility",
  proc { |move, user, target, ai, battle|
    next true if !user.ability || user.ability_id == target.ability_id
    next true if user.battler.ungainableAbility? ||
                 [:POWEROFALCHEMY, :RECEIVER, :TRACE].include?(user.ability_id)
    next true if target.battler.unstoppableAbility? || target.ability_id == :TRUANT
  }
)
Battle::AI::Handlers::MoveEffectScore.add("SetTargetAbilityToUserAbility",
  proc { |score, move, user, target, ai, battle|
    score -= 40   # don't prefer this move
    if ai.trainer.medium_skill? && user.opposes?(target)
      score += 90 if [:TRUANT, :SLOWSTART].include?(user.ability_id)
    end
    next score
  }
)

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("UserTargetSwapAbilities",
  proc { |move, user, target, ai, battle|
    next true if !user.ability || !target.ability
    next true if Settings::MECHANICS_GENERATION <= 5 && user.ability_id == target.ability_id
    next true if user.battler.unstoppableAbility? || user.battler.ungainableAbility? ||
                 user.ability_id == :WONDERGUARD
    next true if target.battler.unstoppableAbility? || target.battler.ungainableAbility? ||
                 target.ability_id == :WONDERGUARD
  }
)
Battle::AI::Handlers::MoveEffectScore.add("UserTargetSwapAbilities",
  proc { |score, move, user, target, ai, battle|
    score -= 40   # don't prefer this move
    if ai.trainer.high_skill? && user.opposes?(target)
      score -= 90 if [:TRUANT, :SLOWSTART].include?(target.ability_id)
    end
    next score
  }
)

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("NegateTargetAbility",
  proc { |move, user, target, ai, battle|
    next move.move.pbFailsAgainstTarget?(user.battler, target.battler, false)
  }
)

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("NegateTargetAbilityIfTargetActed",
  proc { |score, move, user, target, ai, battle|
    score += 15 if target.faster_than?(user)
    next score
  }
)

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
# IgnoreTargetAbility

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("StartUserAirborne",
  proc { |move, user, target, ai, battle|
    next true if user.effects[PBEffects::Ingrain] ||
                 user.effects[PBEffects::SmackDown] ||
                 user.effects[PBEffects::MagnetRise] > 0
  }
)

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("StartTargetAirborneAndAlwaysHitByMoves",
  proc { |move, user, target, ai, battle|
    next move.move.pbFailsAgainstTarget?(user.battler, target.battler, false)
  }
)

#===============================================================================
#
#===============================================================================
# HitsTargetInSky

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("HitsTargetInSkyGroundsTarget",
  proc { |score, move, user, target, ai, battle|
    if ai.trainer.medium_skill?
      score += 20 if target.effects[PBEffects::MagnetRise] > 0 ||
                     target.effects[PBEffects::Telekinesis] > 0 ||
                     target.has_type?(:FLYING) ||
                     (!battle.moldBreaker && target.has_active_ability?(:LEVITATE)) ||
                     target.has_active_item?(:AIRBALLOON) ||
                     target.battler.inTwoTurnAttack?("TwoTurnAttackInvulnerableInSky",
                                                     "TwoTurnAttackInvulnerableInSkyParalyzeTarget")
    end
    next score
  }
)

#===============================================================================
# TODO: Review score modifiers.
# TODO: This code shouldn't make use of target.
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("StartGravity",
  proc { |move, user, target, ai, battle|
    next true if battle.field.effects[PBEffects::Gravity] > 0
  }
)
Battle::AI::Handlers::MoveEffectScore.add("StartGravity",
  proc { |score, move, user, target, ai, battle|
    if ai.trainer.medium_skill?
      score -= 15 if user.effects[PBEffects::SkyDrop] >= 0 ||
                     user.effects[PBEffects::MagnetRise] > 0 ||
                     user.effects[PBEffects::Telekinesis] > 0 ||
                     user.has_type?(:FLYING) ||
                     user.has_active_ability?(:LEVITATE) ||
                     user.has_active_item?(:AIRBALLOON)
      score += 15 if target.effects[PBEffects::SkyDrop] >= 0 ||
                     target.effects[PBEffects::MagnetRise] > 0 ||
                     target.effects[PBEffects::Telekinesis] > 0 ||
                     target.has_type?(:FLYING) ||
                     target.has_active_ability?(:LEVITATE) ||
                     target.has_active_item?(:AIRBALLOON)
      score += 5 if target.battler.inTwoTurnAttack?("TwoTurnAttackInvulnerableInSky",
                                                    "TwoTurnAttackInvulnerableInSkyParalyzeTarget",
                                                    "TwoTurnAttackInvulnerableInSkyTargetCannotAct")
    end
    next score
  }
)

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("TransformUserIntoTarget",
  proc { |move, user, target, ai, battle|
    next true if user.effects[PBEffects::Transform]
    next true if target.effects[PBEffects::Transform] ||
                 target.effects[PBEffects::Illusion]
  }
)
Battle::AI::Handlers::MoveEffectScore.add("TransformUserIntoTarget",
  proc { |score, move, user, target, ai, battle|
    next score - 20
  }
)
