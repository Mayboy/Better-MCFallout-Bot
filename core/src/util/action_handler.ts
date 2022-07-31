import { BotActionMethod } from "@/bot/model/bot_action";
import { Config } from "@/config";
import { EventEmitter } from "@/util/event_emitter";
import { BotAction, BotActionType } from "@/bot/model/bot_action";
import { Bot } from "mineflayer";
import { config } from "@/index";

let _isRaiding = false;

export class ActionHandler {
  static handle(bot: Bot, json: string) {
    const action: BotAction = JSON.parse(json);

    switch (action.action) {
      case BotActionType.none:
        break;
      case BotActionType.raid:
        this._raid(bot, action);
        break;
      case BotActionType.command:
        this._command(bot, action);
        break;
      case BotActionType.updateConfig:
        this._updateConfig(action);
        break;
      case BotActionType.disconnect:
        this._disconnect(bot);
        break;
    }
  }

  static _command(bot: Bot, action: BotAction) {
    const command: string | unknown = action.argument?.command;
    if (typeof command === "string") {
      bot.chat(command);

      EventEmitter.info(`Executed the command: ${command}`);
    } else {
      EventEmitter.error(`Invalid command action: ${action.argument}`);
    }
  }

  static _updateConfig(action: BotAction) {
    const _config: Config | unknown = action.argument?.config;

    if (typeof _config === "object") {
      try {
        const _newConfig = _config as Config;
        config.autoEat = _newConfig.autoEat;
        config.autoThrow = _newConfig.autoThrow;
        config.autoReconnect = _newConfig.autoReconnect;

        EventEmitter.info("Config updated.");
      } catch (error) {
        EventEmitter.error(`Invalid config argument: ${_config} (${error})`);
      }
    } else {
      EventEmitter.error(`Invalid config action: ${action.argument?.config}`);
    }
  }

  static _disconnect(bot: Bot) {
    bot.quit();
  }

  static _raid(bot: Bot, action: BotAction) {
    if (action.method == BotActionMethod.start) {
      if (_isRaiding)
        return EventEmitter.warning("The raid action is already running.");

      _isRaiding = true;

      // Auto attack passive mobs
      setInterval(() => {
        if (!_isRaiding) return;

        const mob_list = [
          "blaze",
          "creeper",
          "drowned",
          "elder_guardian",
          "endermite",
          "evoker",
          "ghast",
          "guardian",
          "hoglin",
          "husk",
          "magma_cube",
          "phantom",
          "piglin_brute",
          "pillager",
          "ravager",
          "shulker",
          "silverfish",
          "skeleton",
          "slime",
          "stray",
          "vex",
          "vindicator",
          "witch",
          "wither_skeleton",
          "zoglin",
          "zombie_villager",
          "enderman",
          "piglin",
          "spider",
          "cave_spider",
          "zombified_piglin",
        ];

        for (const entity_key in bot.entities) {
          const entity = bot.entities[entity_key];
          if (entity.name != null && mob_list.includes(entity.name)) {
            bot.attack(entity);
          }
        }
      }, 1000);
    } else if (action.method == BotActionMethod.stop) {
      if (!_isRaiding)
        return EventEmitter.warning(
          "The raid action is not running, so it cannot be stopped."
        );

      _isRaiding = false;
    }
  }
}
