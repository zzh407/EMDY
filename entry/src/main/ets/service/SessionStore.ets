import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { EmbySession } from '../model/EmbyModels';

const STORE_NAME: string = 'emby_session';
const KEY_SERVER_URL: string = 'server_url';
const KEY_ACCESS_TOKEN: string = 'access_token';
const KEY_USER_ID: string = 'user_id';
const KEY_USER_NAME: string = 'user_name';
const KEY_DEVICE_ID: string = 'device_id';
const KEY_LIBRARY_ID: string = 'library_id';

export class SessionStore {
  private static createDeviceId(): string {
    const randomPart = Math.floor(Math.random() * 1000000000).toString(36);
    return `emdy-${Date.now().toString(36)}-${randomPart}`;
  }

  private static getStore(context: common.UIAbilityContext): preferences.Preferences {
    try {
      return preferences.getPreferencesSync(context, { name: STORE_NAME });
    } catch (error) {
      throw new Error('无法访问本机会话存储');
    }
  }

  static getOrCreateDeviceId(context: common.UIAbilityContext): string {
    try {
      const store = SessionStore.getStore(context);
      const savedId = store.getSync(KEY_DEVICE_ID, '') as string;
      if (savedId.length > 0) {
        return savedId;
      }

      const deviceId = SessionStore.createDeviceId();
      store.putSync(KEY_DEVICE_ID, deviceId);
      store.flushSync();
      return deviceId;
    } catch (error) {
      return SessionStore.createDeviceId();
    }
  }

  static load(context: common.UIAbilityContext): EmbySession | null {
    try {
      const store = SessionStore.getStore(context);
      const serverUrl = store.getSync(KEY_SERVER_URL, '') as string;
      const accessToken = store.getSync(KEY_ACCESS_TOKEN, '') as string;
      const userId = store.getSync(KEY_USER_ID, '') as string;
      const userName = store.getSync(KEY_USER_NAME, '') as string;
      if (serverUrl.length === 0 || accessToken.length === 0 || userId.length === 0) {
        return null;
      }
      return new EmbySession(serverUrl, accessToken, userId, userName);
    } catch (error) {
      return null;
    }
  }

  static save(context: common.UIAbilityContext, session: EmbySession): void {
    try {
      const store = SessionStore.getStore(context);
      store.putSync(KEY_SERVER_URL, session.serverUrl);
      store.putSync(KEY_ACCESS_TOKEN, session.accessToken);
      store.putSync(KEY_USER_ID, session.userId);
      store.putSync(KEY_USER_NAME, session.userName);
      store.flushSync();
    } catch (error) {
      throw new Error('无法保存登录信息');
    }
  }

  static saveLibraryId(context: common.UIAbilityContext, libraryId: string): void {
    try {
      const store = SessionStore.getStore(context);
      store.putSync(KEY_LIBRARY_ID, libraryId);
      store.flushSync();
    } catch (error) {
      return;
    }
  }

  static loadLibraryId(context: common.UIAbilityContext): string {
    try {
      const store = SessionStore.getStore(context);
      return store.getSync(KEY_LIBRARY_ID, '') as string;
    } catch (error) {
      return '';
    }
  }

  static clear(context: common.UIAbilityContext): void {
    try {
      const store = SessionStore.getStore(context);
      store.deleteSync(KEY_SERVER_URL);
      store.deleteSync(KEY_ACCESS_TOKEN);
      store.deleteSync(KEY_USER_ID);
      store.deleteSync(KEY_USER_NAME);
      store.deleteSync(KEY_LIBRARY_ID);
      store.flushSync();
    } catch (error) {
      return;
    }
  }
}
