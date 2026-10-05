export class EmbySession {
  serverUrl: string;
  accessToken: string;
  userId: string;
  userName: string;

  constructor(serverUrl: string = '', accessToken: string = '', userId: string = '', userName: string = '') {
    this.serverUrl = serverUrl;
    this.accessToken = accessToken;
    this.userId = userId;
    this.userName = userName;
  }
}

export type EmbyPlaybackMode = 'direct' | 'hls' | 'original';

export class EmbyVideo {
  id: string;
  name: string;
  overview: string;
  imageUrl: string;
  streamUrl: string;
  durationText: string;
  authorName: string;
  authorAvatar: string;
  width: number;
  height: number;
  playbackModes: Array<EmbyPlaybackMode>;
  directStreamUrl: string;
  hlsStreamUrl: string;
  originalStreamUrl: string;

  constructor(id: string = '', name: string = '', overview: string = '', imageUrl: string = '',
    streamUrl: string = '', durationText: string = '', authorName: string = '', authorAvatar: string = '',
    width: number = 0, height: number = 0, playbackModes: Array<EmbyPlaybackMode> = ['direct'],
    directStreamUrl: string = '', hlsStreamUrl: string = '', originalStreamUrl: string = '') {
    this.id = id;
    this.name = name;
    this.overview = overview;
    this.imageUrl = imageUrl;
    this.streamUrl = streamUrl;
    this.durationText = durationText;
    this.authorName = authorName;
    this.authorAvatar = authorAvatar;
    this.width = width;
    this.height = height;
    this.playbackModes = playbackModes;
    this.directStreamUrl = directStreamUrl;
    this.hlsStreamUrl = hlsStreamUrl;
    this.originalStreamUrl = originalStreamUrl;
  }

  authorInitial(): string {
    if (this.authorName.length > 0) {
      return this.authorName.substring(0, 1);
    }
    return '?';
  }

  isPortrait(): boolean {
    return this.width > 0 && this.height > this.width;
  }

  urlOf(mode: EmbyPlaybackMode): string {
    if (mode === 'hls') {
      return this.hlsStreamUrl;
    }
    if (mode === 'original') {
      return this.originalStreamUrl;
    }
    return this.directStreamUrl;
  }

  labelOf(mode: EmbyPlaybackMode): string {
    if (mode === 'hls') {
      return '转码';
    }
    if (mode === 'original') {
      return '原盘流';
    }
    return '直播放';
  }
}

export class EmbyLibrary {
  id: string;
  name: string;
  collectionType: string;

  constructor(id: string = '', name: string = '', collectionType: string = '') {
    this.id = id;
    this.name = name;
    this.collectionType = collectionType;
  }
}

export interface EmbyViewsSummary {
  total: number;
  text: string;
}

export class EmbyVideoPage {
  items: Array<EmbyVideo>;
  totalRecordCount: number;

  constructor(items: Array<EmbyVideo> = [], totalRecordCount: number = 0) {
    this.items = items;
    this.totalRecordCount = totalRecordCount;
  }
}
