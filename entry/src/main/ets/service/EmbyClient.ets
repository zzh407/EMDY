import { http } from '@kit.NetworkKit';
import { EmbyLibrary, EmbyPlaybackMode, EmbySession, EmbyVideo, EmbyVideoPage, EmbyViewsSummary } from '../model/EmbyModels';

const CLIENT_NAME: string = 'Emdy';
const DEVICE_NAME: string = 'HarmonyOS';
const CLIENT_VERSION: string = '1.0.0';

const UNSUPPORTED_CONTAINERS: Set<string> = new Set<string>([
  'avi', 'wmv', 'mpeg', 'mpg', 'rmvb', 'rm', 'flv', 'asf', 'vob', 'divx', 'mkv'
]);

const COLLECTION_TYPES: Set<string> = new Set<string>([
  'boxset', 'manualplaylistsfolder', 'playlist', 'collectionfolder', 'folder', 'channel', 'channelFolderItem'
]);

export class EmbyVideoQuery {
  libraryId: string = '';
  hideCollections: boolean = false;
}

interface EmbyUserDto {
  Id?: string;
  Name?: string;
}

interface EmbyAuthDto {
  AccessToken?: string;
  User?: EmbyUserDto;
}

interface EmbyMediaStreamDto {
  Type?: string;
  Width?: number;
  Height?: number;
}

interface EmbyMediaSourceDto {
  Container?: string;
}

interface EmbyPersonDto {
  Id?: string;
  Name?: string;
  Type?: string;
  Role?: string;
}

interface EmbyStudioDto {
  Id?: string;
  Name?: string;
}

interface EmbyItemDto {
  Id?: string;
  Name?: string;
  Type?: string;
  Overview?: string;
  PremiereDate?: string;
  ProductionYear?: number;
  RuntimeTicks?: number;
  PrimaryImageItemId?: string;
  CollectionType?: string;
  Path?: string;
  IsFolder?: boolean;
  Container?: string;
  People?: Array<EmbyPersonDto>;
  Studios?: Array<EmbyStudioDto>;
  MediaSources?: Array<EmbyMediaSourceDto>;
  MediaStreams?: Array<EmbyMediaStreamDto>;
}

interface EmbyItemsDto {
  Items?: Array<EmbyItemDto>;
  TotalRecordCount?: number;
}

interface EmbyRequestHeaders {
  'Accept': string;
  'Content-Type': string;
  'X-Emby-Authorization': string;
  'X-Emby-Token'?: string;
}

export class EmbyClient {
  private readonly serverUrl: string;
  private readonly deviceId: string;
  private readonly accessToken: string;
  private readonly userId: string;

  constructor(serverUrl: string, deviceId: string, accessToken: string = '', userId: string = '') {
    this.serverUrl = EmbyClient.normalizeServerUrl(serverUrl);
    this.deviceId = deviceId;
    this.accessToken = accessToken;
    this.userId = userId;
  }

  static normalizeServerUrl(value: string): string {
    let normalized = value.trim();
    if (normalized.length === 0) {
      return '';
    }
    if (!normalized.toLowerCase().startsWith('http://') &&
      !normalized.toLowerCase().startsWith('https://')) {
      normalized = `http://${normalized}`;
    }
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (normalized.toLowerCase().endsWith('/emby')) {
      normalized = normalized.substring(0, normalized.length - 5);
    }
    return normalized;
  }

  async authenticate(userName: string, password: string): Promise<EmbySession> {
    if (this.serverUrl.length === 0) {
      throw new Error('请输入 Emby 服务器地址');
    }

    const body = JSON.stringify({ Username: userName.trim(), Pw: password });
    const result = await this.request('/emby/Users/AuthenticateByName', http.RequestMethod.POST, body, false);
    const auth = JSON.parse(result) as EmbyAuthDto;
    const token = auth.AccessToken ? auth.AccessToken : '';
    const userId = auth.User && auth.User.Id ? auth.User.Id : '';
    const displayName = auth.User && auth.User.Name ? auth.User.Name : userName.trim();
    if (token.length === 0 || userId.length === 0) {
      throw new Error('服务器返回的登录信息不完整');
    }
    return new EmbySession(this.serverUrl, token, userId, displayName);
  }

  async getLibraries(): Promise<Array<EmbyLibrary>> {
    if (this.accessToken.length === 0 || this.userId.length === 0) {
      throw new Error('登录状态已失效，请重新连接');
    }

    const path = `/emby/Users/${encodeURIComponent(this.userId)}/Views?IncludeExternalContent=false`;
    const result = await this.request(path, http.RequestMethod.GET, '', true);
    const response = this.parseItems(result);
    const sourceItems: Array<EmbyItemDto> = response.Items ? response.Items : [];
    const libraries: Array<EmbyLibrary> = [new EmbyLibrary('', '全部媒体库', 'all')];
    sourceItems.forEach((item: EmbyItemDto) => {
      const id = item.Id ? item.Id : '';
      if (id.length === 0) {
        return;
      }
      const name = item.Name ? item.Name : '未命名媒体库';
      const collectionType = item.CollectionType ? item.CollectionType : 'unknown';
      libraries.push(new EmbyLibrary(id, name, collectionType));
    });
    return libraries;
  }

  async getVideos(startIndex: number = 0, limit: number = 20,
    query: EmbyVideoQuery = new EmbyVideoQuery()): Promise<EmbyVideoPage> {
    if (this.accessToken.length === 0 || this.userId.length === 0) {
      throw new Error('登录状态已失效，请重新连接');
    }

    const parentFilter = query.libraryId.length > 0 ? `&ParentId=${encodeURIComponent(query.libraryId)}` : '';
    const baseQuery = `StartIndex=${startIndex}&Limit=${limit}&Recursive=true${parentFilter}` +
      '&Fields=Overview,MediaStreams,Container,MediaSources,People,Studios,PremiereDate,ProductionYear' +
      '&EnableImages=true&ImageTypeLimit=1';
    const queryVariants: Array<string> = [
      `${baseQuery}&SortBy=DateCreated&SortOrder=Descending&IncludeItemTypes=Video`,
      `${baseQuery}&IncludeItemTypes=Video`,
      `${baseQuery}&IncludeItemTypes=Episode`,
      `${baseQuery}&IncludeItemTypes=Movie`
    ];
    if (query.libraryId.length === 0) {
      queryVariants.push(`${baseQuery}&SortBy=DateCreated&SortOrder=Descending`);
    }

    let firstError: string = '';
    for (const current of queryVariants) {
      const path = `/emby/Users/${encodeURIComponent(this.userId)}/Items?${current}`;
      try {
        const result = await this.request(path, http.RequestMethod.GET, '', true);
        const response = this.parseItems(result);
        const sourceItems: Array<EmbyItemDto> = response.Items ? response.Items : [];
        const items: Array<EmbyVideo> = this.toVideos(sourceItems, query.hideCollections);
        if (items.length > 0) {
          return new EmbyVideoPage(items, response.TotalRecordCount ? response.TotalRecordCount : items.length);
        }
      } catch (error) {
        const requestError = error as Error;
        if (firstError.length === 0) {
          firstError = requestError.message && requestError.message.length > 0 ?
            requestError.message : '视频列表请求失败';
        }
      }
    }

    if (firstError.length > 0) {
      throw new Error(firstError);
    }
    return new EmbyVideoPage([], 0);
  }

  async getViewsSummary(): Promise<EmbyViewsSummary> {
    if (this.accessToken.length === 0 || this.userId.length === 0) {
      return { total: 0, text: '登录状态已失效' };
    }
    return this.describeLibraries();
  }

  async describeLibraries(): Promise<EmbyViewsSummary> {

    const path = `/emby/Users/${encodeURIComponent(this.userId)}/Views?IncludeExternalContent=false`;
    try {
      const result = await this.request(path, http.RequestMethod.GET, '', true);
      const response = this.parseItems(result);
      const sourceItems: Array<EmbyItemDto> = response.Items ? response.Items : [];
      const parts: Array<string> = sourceItems.map((item: EmbyItemDto) => {
        const type = item.CollectionType ? item.CollectionType : 'unknown';
        const name = item.Name ? item.Name : '未命名';
        return `${name}(${type})`;
      });
      const text = parts.length > 0 ? parts.join('，') : '当前用户没有可见媒体库';
      return { total: sourceItems.length, text: text.length > 200 ? `${text.substring(0, 200)}…` : text };
    } catch (error) {
      const requestError = error as Error;
      return { total: 0, text: requestError.message ? requestError.message : '无法读取媒体库' };
    }
  }

  private parseItems(raw: string): EmbyItemsDto {
    try {
      const parsed = JSON.parse(raw) as EmbyItemsDto;
      if (!parsed.Items) {
        return { Items: [], TotalRecordCount: 0 };
      }
      return parsed;
    } catch (error) {
      throw new Error('服务器返回的视频列表无法解析');
    }
  }

  private toVideos(sourceItems: Array<EmbyItemDto>, hideCollections: boolean): Array<EmbyVideo> {
    const items: Array<EmbyVideo> = [];
    sourceItems.forEach((item: EmbyItemDto) => {
      if (hideCollections && this.isCollection(item)) {
        return;
      }
      items.push(this.toVideo(item));
    });
    return items;
  }

  private isCollection(item: EmbyItemDto): boolean {
    if (item.IsFolder === true) {
      return true;
    }
    if (item.Type && COLLECTION_TYPES.has(item.Type.toLowerCase())) {
      return true;
    }
    if (item.CollectionType && COLLECTION_TYPES.has(item.CollectionType.toLowerCase())) {
      return true;
    }
    return false;
  }

  private pickAuthor(item: EmbyItemDto): EmbyPersonDto | null {
    const people: Array<EmbyPersonDto> = item.People ? item.People : [];
    const director = people.find((person: EmbyPersonDto) => person.Type === 'Director');
    if (director) {
      return director;
    }
    const writer = people.find((person: EmbyPersonDto) => person.Type === 'Writer');
    if (writer) {
      return writer;
    }
    const named = people.find((person: EmbyPersonDto) =>
      person.Name !== undefined && (person.Name as string).length > 0);
    return named ? named : null;
  }

  private pickStudio(item: EmbyItemDto): EmbyStudioDto | null {
    const studios: Array<EmbyStudioDto> = item.Studios ? item.Studios : [];
    const named = studios.find((studio: EmbyStudioDto) =>
      studio.Name !== undefined && (studio.Name as string).length > 0);
    return named ? named : null;
  }

  private buildAuthorName(item: EmbyItemDto): string {
    const author = this.pickAuthor(item);
    if (author && author.Name && author.Name.length > 0) {
      return author.Name;
    }
    const studio = this.pickStudio(item);
    if (studio && studio.Name) {
      return studio.Name;
    }
    return '';
  }

  private buildAuthorAvatar(item: EmbyItemDto): string {
    const author = this.pickAuthor(item);
    if (author && author.Id && author.Id.length > 0) {
      return this.buildImageUrl(author.Id, 160);
    }
    const studio = this.pickStudio(item);
    if (studio && studio.Id && studio.Id.length > 0) {
      return this.buildImageUrl(studio.Id, 160);
    }
    return '';
  }

  private readYear(item: EmbyItemDto): string {
    if (item.ProductionYear !== undefined && item.ProductionYear > 0) {
      return `${item.ProductionYear}`;
    }
    if (item.PremiereDate && item.PremiereDate.length >= 4) {
      return item.PremiereDate.substring(0, 4);
    }
    return '';
  }

  private toVideo(item: EmbyItemDto): EmbyVideo {
    const id = item.Id ? item.Id : '';
    const name = item.Name ? item.Name : '未命名视频';
    const overview = item.Overview ? item.Overview : '';
    const imageItemId = item.PrimaryImageItemId ? item.PrimaryImageItemId : id;
    let width = 0;
    let height = 0;
    if (item.MediaStreams) {
      const videoStream = item.MediaStreams.find((stream: EmbyMediaStreamDto) => stream.Type === 'Video');
      if (videoStream) {
        width = videoStream.Width ? videoStream.Width : 0;
        height = videoStream.Height ? videoStream.Height : 0;
      }
    }
    const playbackModes = this.buildPlaybackModes(item);
    const firstMode: EmbyPlaybackMode = playbackModes[0];
    return new EmbyVideo(id, name, overview, this.buildImageUrl(imageItemId), this.buildUrl(id, firstMode),
      this.formatDuration(item.RuntimeTicks ? item.RuntimeTicks : 0), this.buildAuthorName(item),
      this.buildAuthorAvatar(item), width, height, playbackModes, this.buildUrl(id, 'direct'),
      this.buildUrl(id, 'hls'), this.buildUrl(id, 'original'));
  }

  private buildPlaybackModes(item: EmbyItemDto): Array<EmbyPlaybackMode> {
    const container = this.readContainer(item);
    if (container.length > 0 && UNSUPPORTED_CONTAINERS.has(container)) {
      return ['hls', 'direct', 'original'];
    }
    return ['direct', 'hls', 'original'];
  }

  private readContainer(item: EmbyItemDto): string {
    if (item.Container && item.Container.length > 0) {
      return item.Container.toLowerCase();
    }
    if (item.MediaSources) {
      const source = item.MediaSources.find((mediaSource: EmbyMediaSourceDto) =>
        mediaSource.Container !== undefined && (mediaSource.Container as string).length > 0);
      if (source && source.Container) {
        return source.Container.toLowerCase();
      }
    }
    if (item.Path) {
      const segments: Array<string> = item.Path.split('.');
      if (segments.length > 1) {
        return segments[segments.length - 1].toLowerCase();
      }
    }
    return '';
  }

  private buildUrl(itemId: string, mode: EmbyPlaybackMode): string {
    if (mode === 'hls') {
      return `${this.serverUrl}/emby/Videos/${encodeURIComponent(itemId)}/master.m3u8` +
        '?VideoCodec=h264&AudioCodec=aac&SegmentContainer=ts&MaxWidth=1280&VideoBitrate=6000000' +
        '&AudioBitrate=192000&EnableAdaptiveBitrateStreaming=false&BreakOnNonKeyFrames=false' +
        `&api_key=${encodeURIComponent(this.accessToken)}&DeviceId=${encodeURIComponent(this.deviceId)}`;
    }
    if (mode === 'original') {
      return `${this.serverUrl}/emby/Videos/${encodeURIComponent(itemId)}/original` +
        `?api_key=${encodeURIComponent(this.accessToken)}&DeviceId=${encodeURIComponent(this.deviceId)}`;
    }
    return `${this.serverUrl}/emby/Videos/${encodeURIComponent(itemId)}/stream` +
      `?Static=true&api_key=${encodeURIComponent(this.accessToken)}` +
      `&DeviceId=${encodeURIComponent(this.deviceId)}`;
  }

  private buildImageUrl(itemId: string, maxWidth: number = 1080): string {
    return `${this.serverUrl}/emby/Items/${encodeURIComponent(itemId)}/Images/Primary` +
      `?maxWidth=${maxWidth}&quality=85&api_key=${encodeURIComponent(this.accessToken)}`;
  }

  private formatDuration(runtimeTicks: number): string {
    if (runtimeTicks <= 0) {
      return '';
    }
    const totalSeconds: number = Math.floor(runtimeTicks / 10000000);
    const remainingAfterHours: number = totalSeconds % 3600;
    const hours: number = Math.floor(totalSeconds / 3600);
    const minutes: number = Math.floor(remainingAfterHours / 60);
    const seconds: number = remainingAfterHours % 60;
    const paddedSeconds = seconds < 10 ? `0${seconds}` : `${seconds}`;
    if (hours > 0) {
      const paddedMinutes = minutes < 10 ? `0${minutes}` : `${minutes}`;
      return `${hours}:${paddedMinutes}:${paddedSeconds}`;
    }
    return `${minutes}:${paddedSeconds}`;
  }

  private authorizationHeader(): string {
    return `MediaBrowser Client="${CLIENT_NAME}", Device="${DEVICE_NAME}", ` +
      `DeviceId="${this.deviceId}", Version="${CLIENT_VERSION}"`;
  }

  private async request(path: string, method: http.RequestMethod, body: string,
    includeToken: boolean): Promise<string> {
    const request = http.createHttp();
    let header: Object;
    if (includeToken) {
      const authenticatedHeader: EmbyRequestHeaders = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Emby-Authorization': this.authorizationHeader(),
        'X-Emby-Token': this.accessToken
      };
      header = authenticatedHeader;
    } else {
      const anonymousHeader: EmbyRequestHeaders = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Emby-Authorization': this.authorizationHeader()
      };
      header = anonymousHeader;
    }
    const options: http.HttpRequestOptions = {
      method: method,
      header: header,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 15000,
      readTimeout: 30000,
      usingCache: false
    };
    if (body.length > 0) {
      options.extraData = body;
    }

    try {
      const response = await request.request(`${this.serverUrl}${path}`, options);
      if (response.responseCode < 200 || response.responseCode >= 300) {
        if (response.responseCode === 401) {
          throw new Error('用户名、密码或登录令牌无效');
        }
        throw new Error(`Emby 服务器返回错误：${response.responseCode}`);
      }
      if (response.result === undefined || response.result === null) {
        return '';
      }
      if (typeof response.result !== 'string') {
        return JSON.stringify(response.result);
      }
      return response.result;
    } catch (error) {
      const requestError = error as Error;
      if (requestError.message && requestError.message.length > 0) {
        throw new Error(requestError.message);
      }
      throw new Error('网络请求失败，请检查服务器地址和网络');
    } finally {
      request.destroy();
    }
  }
}
