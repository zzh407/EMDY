import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const STORE_NAME: string = 'emdy_settings';
const KEY_SERVER_URL: string = 'login_server_url';
const KEY_USER_NAME: string = 'login_user_name';
const KEY_PASSWORD: string = 'login_password';
const KEY_REMEMBER: string = 'login_remember';
const KEY_HIDE_COLLECTIONS: string = 'hide_collections';
const KEY_SHUFFLE: string = 'play_shuffle';

export class AppSettings {
  private static getStore(context: common.UIAbilityContext): preferences.Preferences {
    try {
      return preferences.getPreferencesSync(context, { name: STORE_NAME });
    } catch (error) {
      throw new Error('无法访问本机设置存储');
    }
  }

  static loadLogin(context: common.UIAbilityContext): Array<string> {
    try {
      const store = AppSettings.getStore(context);
      const remember = store.getSync(KEY_REMEMBER, false) as boolean;
      const serverUrl = store.getSync(KEY_SERVER_URL, '') as string;
      const userName = store.getSync(KEY_USER_NAME, '') as string;
      const password = store.getSync(KEY_PASSWORD, '') as string;
      return [remember ? '1' : '0', serverUrl, userName, password];
    } catch (error) {
      return ['0', '', '', ''];
    }
  }

  static saveLogin(context: common.UIAbilityContext, serverUrl: string, userName: string,
    password: string): void {
    try {
      const store = AppSettings.getStore(context);
      store.putSync(KEY_REMEMBER, true);
      store.putSync(KEY_SERVER_URL, serverUrl);
      store.putSync(KEY_USER_NAME, userName);
      store.putSync(KEY_PASSWORD, password);
      store.flushSync();
    } catch (error) {
      return;
    }
  }

  static clearLogin(context: common.UIAbilityContext): void {
    try {
      const store = AppSettings.getStore(context);
      store.putSync(KEY_REMEMBER, false);
      store.putSync(KEY_SERVER_URL, '');
      store.putSync(KEY_USER_NAME, '');
      store.putSync(KEY_PASSWORD, '');
      store.flushSync();
    } catch (error) {
      return;
    }
  }

  static saveHideCollections(context: common.UIAbilityContext, hide: boolean): void {
    try {
      const store = AppSettings.getStore(context);
      store.putSync(KEY_HIDE_COLLECTIONS, hide);
      store.flushSync();
    } catch (error) {
      return;
    }
  }

  static loadHideCollections(context: common.UIAbilityContext): boolean {
    try {
      const store = AppSettings.getStore(context);
      return store.getSync(KEY_HIDE_COLLECTIONS, false) as boolean;
    } catch (error) {
      return false;
    }
  }

  static saveShuffle(context: common.UIAbilityContext, shuffle: boolean): void {
    try {
      const store = AppSettings.getStore(context);
      store.putSync(KEY_SHUFFLE, shuffle);
      store.flushSync();
    } catch (error) {
      return;
    }
  }

  static loadShuffle(context: common.UIAbilityContext): boolean {
    try {
      const store = AppSettings.getStore(context);
      return store.getSync(KEY_SHUFFLE, false) as boolean;
    } catch (error) {
      return false;
    }
  }
}
