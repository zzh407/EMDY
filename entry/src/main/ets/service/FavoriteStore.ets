import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { EmbyVideo, EmbyPlaybackMode } from '../model/EmbyModels';

const STORE_NAME: string = 'emdy_settings';
const KEY_FAVORITES: string = 'favorite_videos';

interface PlainVideo {
  id?: string;
  name?: string;
  overview?: string;
  imageUrl?: string;
  streamUrl?: string;
  durationText?: string;
  authorName?: string;
  authorAvatar?: string;
  width?: number;
  height?: number;
  playbackModes?: Array<EmbyPlaybackMode>;
  directStreamUrl?: string;
  hlsStreamUrl?: string;
  originalStreamUrl?: string;
  originalIndex?: number;
}

export class FavoriteStore {
  static load(context: common.UIAbilityContext): Array<EmbyVideo> {
    try {
      const store = preferences.getPreferencesSync(context, { name: STORE_NAME });
      const raw = store.getSync(KEY_FAVORITES, '') as string;
      if (raw.length === 0) {
        return [];
      }
      const parsed = JSON.parse(raw) as Array<PlainVideo>;
      const videos: Array<EmbyVideo> = [];
      parsed.forEach((plain: PlainVideo) => {
        const id = plain.id ? plain.id : '';
        if (id.length === 0) {
          return;
        }
        videos.push(new EmbyVideo(
          id,
          plain.name ? plain.name : '',
          plain.overview ? plain.overview : '',
          plain.imageUrl ? plain.imageUrl : '',
          plain.streamUrl ? plain.streamUrl : '',
          plain.durationText ? plain.durationText : '',
          plain.authorName ? plain.authorName : '',
          plain.authorAvatar ? plain.authorAvatar : '',
          plain.width ? plain.width : 0,
          plain.height ? plain.height : 0,
          plain.playbackModes && plain.playbackModes.length > 0 ? plain.playbackModes : ['direct'],
          plain.directStreamUrl ? plain.directStreamUrl : '',
          plain.hlsStreamUrl ? plain.hlsStreamUrl : '',
          plain.originalStreamUrl ? plain.originalStreamUrl : '',
          plain.originalIndex ? plain.originalIndex : 0
        ));
      });
      return videos;
    } catch (error) {
      return [];
    }
  }

  static save(context: common.UIAbilityContext, videos: Array<EmbyVideo>): void {
    try {
      const store = preferences.getPreferencesSync(context, { name: STORE_NAME });
      const plainList: Array<PlainVideo> = videos.map((video: EmbyVideo): PlainVideo => {
        const plain: PlainVideo = {
          id: video.id,
          name: video.name,
          overview: video.overview,
          imageUrl: video.imageUrl,
          streamUrl: video.streamUrl,
          durationText: video.durationText,
          authorName: video.authorName,
          authorAvatar: video.authorAvatar,
          width: video.width,
          height: video.height,
          playbackModes: video.playbackModes,
          directStreamUrl: video.directStreamUrl,
          hlsStreamUrl: video.hlsStreamUrl,
          originalStreamUrl: video.originalStreamUrl,
          originalIndex: video.originalIndex
        };
        return plain;
      });
      store.putSync(KEY_FAVORITES, JSON.stringify(plainList));
      store.flushSync();
    } catch (error) {
      return;
    }
  }
}
