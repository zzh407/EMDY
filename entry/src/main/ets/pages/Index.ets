import { common } from '@kit.AbilityKit';
import { display, window } from '@kit.ArkUI';
import { AppSettings } from '../service/AppSettings';
import { FavoriteStore } from '../service/FavoriteStore';
import { EmbyClient, EmbyVideoQuery } from '../service/EmbyClient';
import { SessionStore } from '../service/SessionStore';
import { ShortVideoCard } from './ShortVideoCard';
import { EmbyLibrary, EmbySession, EmbyVideo, EmbyVideoPage, EmbyViewsSummary } from '../model/EmbyModels';


@Entry
@Component
struct Index {
  @State serverUrl: string = '';
  @State userName: string = '';
  @State password: string = '';
  @State session: EmbySession | null = null;
  @State videos: Array<EmbyVideo> = [];
  @State currentIndex: number = 0;
  @State totalRecordCount: number = 0;
  @State isConnecting: boolean = false;
  @State isLoading: boolean = false;
  @State hasMore: boolean = true;
  @State muted: boolean = true;
  @State errorMessage: string = '';
  @State debugInfo: string = '';
  @State libraries: Array<EmbyLibrary> = [];
  @State selectedLibraryId: string = '';
  @State selectedLibraryName: string = '全部媒体库';
  @State libraryPickerVisible: boolean = false;
  @State rememberLogin: boolean = false;
  @State hideCollections: boolean = false;
  @State shufflePlayback: boolean = false;
  @State fastSpeed: number = 2.0;
  @State optionsVisible: boolean = false;
  @State topSafePadding: number = 0;
  @State bottomSafePadding: number = 0;
  @State immersive: boolean = true;
  @State controlsHidden: boolean = false;
  @State hintText: string = '';
  @State mediaListVisible: boolean = false;
  @State mediaListItems: Array<EmbyVideo> = [];
  @State mediaListLoading: boolean = false;
  @State mediaListHasMore: boolean = true;
  @State mediaListTotal: number = 0;
  @State multiSelectMode: boolean = false;
  @State selectedIds: Array<string> = [];
  @State batchDeletePending: boolean = false;
  private lastLongPressTime: number = 0;
  private deviceId: string = '';
  private client: EmbyClient | null = null;
  private hintTimer: number = 0;
  @State private favorites: Array<EmbyVideo> = [];
  @State private deletePending: boolean = false;
  @State private deleteConfirmVisible: boolean = false;
  @State private deleteConfirmTitle: string = '';
  @State private deleteConfirmMode: string = 'single';
  private deleteConfirmItem: EmbyVideo = new EmbyVideo();
  private deleteAfterAnimId: string = '';
  private deleteAnimTimer: number = 0;
  private reloadAfterDelete: boolean = false;
  @State private filterAuthorName: string = '';
  @State private filterTagName: string = '';
  @State private filterTagKind: string = '';
  private resumeLibraryId: string = '';
  private resumeLibraryName: string = '';
  private resumeShuffle: boolean = false;
  private restoreEyeCanvas: CanvasRenderingContext2D = new CanvasRenderingContext2D();
  private swiperController: SwiperController = new SwiperController();
  private feedSourceCount: number = 0;
  private gridScroller: Scroller = new Scroller();

  private readonly pageSize: number = 20;

  private getAbilityContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private async applyImmersiveMode(): Promise<void> {
    try {
      const context = this.getAbilityContext();
      const windowStage = context.windowStage;
      if (!windowStage) {
        this.topSafePadding = 0;
        this.bottomSafePadding = 0;
        return;
      }
      const mainWindow: window.Window = await windowStage.getMainWindow();
      await mainWindow.setWindowLayoutFullScreen(this.immersive);
      const uiContext = this.getUIContext();
      const systemArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const cutoutArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      const statusHeightPx = systemArea.topRect.height > cutoutArea.topRect.height ?
        systemArea.topRect.height : cutoutArea.topRect.height;
      this.topSafePadding = uiContext.px2vp(statusHeightPx);
      this.bottomSafePadding = uiContext.px2vp(systemArea.bottomRect.height);
      mainWindow.off('avoidAreaChange');
      mainWindow.on('avoidAreaChange', (data: window.AvoidAreaOptions) => {
        if (data.type !== window.AvoidAreaType.TYPE_SYSTEM && data.type !== window.AvoidAreaType.TYPE_CUTOUT) {
          return;
        }
        const areaHeightVp = uiContext.px2vp(data.area.topRect.height);
        if (areaHeightVp > this.topSafePadding) {
          this.topSafePadding = areaHeightVp;
        }
      });
    } catch (error) {
      this.topSafePadding = 0;
      this.bottomSafePadding = 0;
    }
  }

  private toggleImmersive(): void {
    this.immersive = !this.immersive;
    this.applyImmersiveMode();
  }

  private topInset(): number {
    return (this.topSafePadding > 0 ? this.topSafePadding : 24) + 10;
  }

  private bottomInset(): number {
    return this.bottomSafePadding > 0 ? this.bottomSafePadding + 24 : 40;
  }

  aboutToAppear(): void {
    const context = this.getAbilityContext();
    this.applyImmersiveMode();
    this.deviceId = SessionStore.getOrCreateDeviceId(context);
    this.hideCollections = AppSettings.loadHideCollections(context);
    this.fastSpeed = AppSettings.loadFastSpeed(context);
    this.favorites = FavoriteStore.load(context);
    const savedLogin: Array<string> = AppSettings.loadLogin(context);
    this.rememberLogin = savedLogin[0] === '1';
    const savedSession = SessionStore.load(context);
    if (savedSession) {
      this.serverUrl = savedSession.serverUrl;
      this.userName = savedSession.userName;
      if (this.rememberLogin && savedLogin[3].length > 0) {
        this.password = savedLogin[3];
      }
      this.session = savedSession;
      this.client = new EmbyClient(savedSession.serverUrl, this.deviceId, savedSession.accessToken,
        savedSession.userId);
      this.selectedLibraryId = SessionStore.loadLibraryId(context);
      this.loadLibraries();
      this.loadVideos(true);
    } else if (this.rememberLogin) {
      this.serverUrl = savedLogin[1];
      this.userName = savedLogin[2];
      this.password = savedLogin[3];
    }
  }

  private async loadLibraries(): Promise<void> {
    const client = this.client;
    if (client === null) {
      return;
    }
    try {
      const libraries: Array<EmbyLibrary> = await client.getLibraries();
      libraries.unshift(new EmbyLibrary('favorites', '喜欢', 'favorites'));
      this.libraries = libraries;
      this.applyLibrarySelection(libraries, this.selectedLibraryId);
    } catch (error) {
      this.libraries = [
        new EmbyLibrary('favorites', '喜欢', 'favorites'),
        new EmbyLibrary('', '全部媒体库', 'all')
      ];
    }
  }

  private applyLibrarySelection(libraries: Array<EmbyLibrary>, libraryId: string): void {
    let matched: EmbyLibrary | null = null;
    libraries.forEach((library: EmbyLibrary) => {
      if (library.id === libraryId) {
        matched = library;
      }
    });
    const target = matched ? matched as EmbyLibrary : libraries[0];
    this.selectedLibraryId = target.id;
    this.selectedLibraryName = target.name;
  }

  private isFavoriteLibrary(): boolean {
    return this.selectedLibraryId === 'favorites';
  }

  private isAuthorFiltered(): boolean {
    return this.filterAuthorName.length > 0;
  }

  private isTagFiltered(): boolean {
    return this.filterTagName.length > 0;
  }

  private isFiltered(): boolean {
    return this.isAuthorFiltered() || this.isTagFiltered();
  }

  private async openAuthorFeed(item: EmbyVideo): Promise<void> {
    const client = this.client;
    if (client === null) {
      this.showHint('尚未连接服务器');
      return;
    }
    const author = item.authorName.length > 0 ? item.authorName : '';
    if (this.filterAuthorName === author) {
      return;
    }
    if (!this.isFiltered()) {
      this.resumeLibraryId = this.selectedLibraryId;
      this.resumeLibraryName = this.selectedLibraryName;
      this.resumeShuffle = this.shufflePlayback;
    }
    this.filterAuthorName = author;
    this.filterTagName = '';
    if (this.shufflePlayback) {
      this.shufflePlayback = false;
      AppSettings.saveShuffle(this.getAbilityContext(), false);
    }
    this.selectedLibraryId = '';
    this.selectedLibraryName = author.length > 0 ? `@${author}` : '未标注作者';
    this.showHint(author.length > 0 ? `正在筛选 @${author} 的视频` : '正在筛选未标注作者的视频');
    this.mediaListVisible = false;
    await this.loadVideos(true);
  }

  private async openTagFeed(tag: string, kind: string): Promise<void> {
    const client = this.client;
    if (client === null) {
      this.showHint('尚未连接服务器');
      return;
    }
    if (this.filterTagName === tag && this.filterTagKind === kind) {
      return;
    }
    if (!this.isFiltered()) {
      this.resumeLibraryId = this.selectedLibraryId;
      this.resumeLibraryName = this.selectedLibraryName;
      this.resumeShuffle = this.shufflePlayback;
    }
    this.filterTagName = tag;
    this.filterTagKind = kind;
    this.filterAuthorName = '';
    if (this.shufflePlayback) {
      this.shufflePlayback = false;
      AppSettings.saveShuffle(this.getAbilityContext(), false);
    }
    this.selectedLibraryName = `#${tag}`;
    this.showHint(`正在筛选 #${tag} 的视频`);
    this.mediaListVisible = false;
    await this.loadVideos(true);
  }

  private async clearFilter(): Promise<void> {
    if (!this.isFiltered()) {
      return;
    }
    const wasFiltered = this.isFiltered();
    this.filterAuthorName = '';
    this.filterTagName = '';
    this.filterTagKind = '';
    this.selectedLibraryId = this.resumeLibraryId;
    this.selectedLibraryName = this.resumeLibraryName;
    if (this.resumeShuffle && !this.shufflePlayback) {
      this.shufflePlayback = true;
      AppSettings.saveShuffle(this.getAbilityContext(), true);
    }
    if (wasFiltered) {
      this.showHint('已恢复全部视频');
    }
    await this.loadVideos(true);
  }

  private isFavoriteVideo(video: EmbyVideo): boolean {
    return this.favorites.some((item: EmbyVideo) => item.id === video.id);
  }

  private confirmDeleteVideo(item: EmbyVideo): void {
    if (this.deletePending) {
      return;
    }
    this.deleteConfirmItem = item;
    this.deleteConfirmMode = 'single';
    const name = item.name;
    this.deleteConfirmTitle = name.length > 20 ? `${name.substring(0, 20)}…` : (name.length > 0 ? name : '该视频');
    this.deleteConfirmVisible = true;
  }

  private async deleteCurrentVideo(item: EmbyVideo): Promise<void> {
    const client = this.client;
    if (client === null || this.deletePending) {
      return;
    }
    this.deletePending = true;
    this.showHint('正在删除…');
    let keepPending = false;
    try {
      await client.deleteItem(item.id);
      this.removeFavoriteRecord(item.id);
      if (this.totalRecordCount > 0) {
        this.totalRecordCount--;
      }
      const deletedIndex = this.videos.findIndex((video: EmbyVideo) => video.id === item.id);
      if (deletedIndex < 0) {
        this.showHint('已删除');
        return;
      }
      if (this.videos.length <= 1) {
        this.videos.splice(deletedIndex, 1);
        if (this.feedSourceCount > 0) {
          this.feedSourceCount--;
        }
        this.currentIndex = 0;
        this.showHint('已删除，正在重新加载列表');
        await this.reloadAfterEmpty();
        return;
      }
      if (deletedIndex === this.currentIndex) {
        // 与连播跳转保持一致的滑动动画：先滑走，动画结束后再移除数据。
        // keepPending：动画期间保持锁定，由 applyPendingDelete 收尾释放，
        // 避免用户在 300ms 窗口内滑动造成索引交叉。
        const target = deletedIndex < this.videos.length - 1 ? deletedIndex + 1 : deletedIndex - 1;
        this.deleteAfterAnimId = item.id;
        keepPending = true;
        this.swiperController.changeIndex(target, true);
        this.deleteAnimTimer = setTimeout(() => {
          this.deleteAnimTimer = 0;
          this.applyPendingDelete();
        }, 300);
        return;
      }
      this.videos.splice(deletedIndex, 1);
      if (this.feedSourceCount > 0) {
        this.feedSourceCount--;
      }
      if (this.currentIndex > deletedIndex) {
        this.currentIndex--;
        this.syncSwiperIndex();
      }
      this.showHint('已删除');
    } catch (error) {
      this.showHint(`删除失败：${this.describeError(error as Error)}`);
    } finally {
      if (!keepPending) {
        this.deletePending = false;
      }
    }
  }

  private syncSwiperIndex(): void {
    // 数据变化先让 ForEach 落地，下一帧再同步 Swiper，避免同帧竞争导致相邻卡片重排卡顿
    setTimeout(() => {
      if (this.currentIndex < 0 || this.currentIndex >= this.videos.length) {
        // 数据已变化导致索引无效，交由 .index 绑定处理，避免越界 changeIndex
        return;
      }
      this.swiperController.changeIndex(this.currentIndex, false);
    }, 32);
  }

  private applyPendingDelete(): void {
    const id = this.deleteAfterAnimId;
    this.deleteAfterAnimId = '';
    if (id.length === 0) {
      this.deletePending = false;
      return;
    }
    const index = this.videos.findIndex((video: EmbyVideo) => video.id === id);
    if (index < 0) {
      this.deletePending = false;
      return;
    }
    try {
      this.videos.splice(index, 1);
      if (this.feedSourceCount > 0) {
        this.feedSourceCount--;
      }
      if (this.currentIndex > index) {
        // 动画滑到了下一项：删除后该项前移到 index，修正索引保持画面内容不变
        this.currentIndex--;
      }
      if (this.currentIndex >= this.videos.length) {
        this.currentIndex = Math.max(0, this.videos.length - 1);
      }
      this.syncSwiperIndex();
      this.showHint('已删除');
    } finally {
      this.deletePending = false;
    }
  }

  private async reloadAfterEmpty(): Promise<void> {
    if (this.isLoading) {
      // 预加载请求在飞行中，loadVideos 会被忽略，落地后再重试
      this.reloadAfterDelete = true;
      return;
    }
    await this.loadVideos(true);
  }

  private removeFavoriteRecord(id: string): void {
    const favIndex = this.favorites.findIndex((video: EmbyVideo) => video.id === id);
    if (favIndex >= 0) {
      this.favorites.splice(favIndex, 1);
      FavoriteStore.save(this.getAbilityContext(), this.favorites);
    }
  }

  private enterMultiSelect(item: EmbyVideo): void {
    if (this.batchDeletePending) {
      return;
    }
    this.lastLongPressTime = Date.now();
    this.multiSelectMode = true;
    if (!this.selectedIds.includes(item.id)) {
      this.selectedIds.push(item.id);
    }
  }

  private exitMultiSelect(): void {
    if (this.batchDeletePending) {
      return;
    }
    this.multiSelectMode = false;
    this.selectedIds = [];
  }

  private toggleSelect(item: EmbyVideo): void {
    if (this.batchDeletePending) {
      return;
    }
    const index = this.selectedIds.indexOf(item.id);
    if (index >= 0) {
      this.selectedIds.splice(index, 1);
    } else {
      this.selectedIds.push(item.id);
    }
  }

  private toggleSelectAll(): void {
    if (this.batchDeletePending) {
      return;
    }
    if (this.selectedIds.length >= this.mediaListItems.length && this.mediaListItems.length > 0) {
      this.selectedIds = [];
    } else {
      this.selectedIds = this.mediaListItems.map((item: EmbyVideo) => item.id);
    }
  }

  private confirmBatchDelete(): void {
    if (this.batchDeletePending || this.selectedIds.length === 0) {
      return;
    }
    this.deleteConfirmMode = 'batch';
    this.deleteConfirmVisible = true;
  }

  private async batchDeleteSelected(): Promise<void> {
    const client = this.client;
    if (client === null || this.batchDeletePending || this.selectedIds.length === 0) {
      return;
    }
    const ids = this.selectedIds.slice();
    this.batchDeletePending = true;
    this.showHint(`正在删除 ${ids.length} 个视频…`);
    const success: Array<string> = [];
    let failCount = 0;
    for (const id of ids) {
      if (this.client === null) {
        failCount += ids.length - success.length;
        break;
      }
      try {
        await client.deleteItem(id);
        success.push(id);
      } catch (error) {
        failCount++;
      }
    }
    if (success.length > 0) {
      const deletedSet = new Set(success);
      this.mediaListItems = this.mediaListItems.filter((item: EmbyVideo) => !deletedSet.has(item.id));
      if (this.mediaListTotal >= success.length) {
        this.mediaListTotal -= success.length;
      }
      const removedFavCount = this.favorites.filter((item: EmbyVideo) => deletedSet.has(item.id)).length;
      if (removedFavCount > 0) {
        this.favorites = this.favorites.filter((item: EmbyVideo) => !deletedSet.has(item.id));
        FavoriteStore.save(this.getAbilityContext(), this.favorites);
      }
      if (this.totalRecordCount >= success.length) {
        this.totalRecordCount -= success.length;
      }
      await this.syncFeedAfterBatchDelete(deletedSet);
      this.selectedIds = [];
      if (this.mediaListItems.length === 0 && this.mediaListHasMore) {
        this.loadMediaListPage();
      }
    }
    this.multiSelectMode = false;
    this.batchDeletePending = false;
    if (failCount > 0) {
      this.showHint(`已删除 ${success.length} 个，${failCount} 个失败`);
    } else {
      this.showHint(`已删除 ${success.length} 个视频`);
    }
  }

  private async syncFeedAfterBatchDelete(deletedSet: Set<string>): Promise<void> {
    if (this.videos.length === 0) {
      return;
    }
    const currentId = this.currentIndex >= 0 && this.currentIndex < this.videos.length
      ? this.videos[this.currentIndex].id : '';
    let removedBefore = 0;
    for (let i = 0; i < this.currentIndex && i < this.videos.length; i++) {
      if (deletedSet.has(this.videos[i].id)) {
        removedBefore++;
      }
    }
    this.videos = this.videos.filter((item: EmbyVideo) => !deletedSet.has(item.id));
    this.feedSourceCount = this.videos.length;
    if (currentId.length === 0) {
      return;
    }
    if (deletedSet.has(currentId)) {
      if (this.videos.length === 0) {
        this.currentIndex = 0;
        await this.reloadAfterEmpty();
        return;
      }
      const target = this.currentIndex - removedBefore;
      this.currentIndex = Math.max(0, Math.min(target, this.videos.length - 1));
      this.syncSwiperIndex();
    } else {
      this.currentIndex = Math.max(0, this.currentIndex - removedBefore);
    }
  }

  private toggleFavorite(item: EmbyVideo): void {
    const index = this.favorites.findIndex((video: EmbyVideo) => video.id === item.id);
    if (index >= 0) {
      this.favorites.splice(index, 1);
      this.showHint('已取消喜欢');
    } else {
      this.favorites.push(item);
      this.showHint('已加入喜欢');
    }
    FavoriteStore.save(this.getAbilityContext(), this.favorites);
    if (this.isFavoriteLibrary()) {
      this.videos = this.favorites.slice();
      this.hasMore = false;
      this.totalRecordCount = this.videos.length;
    }
  }

  private selectLibrary(library: EmbyLibrary): void {
    if (this.isFiltered()) {
      this.filterAuthorName = '';
      this.filterTagName = '';
      this.filterTagKind = '';
    }
    this.selectedLibraryId = library.id;
    this.selectedLibraryName = library.name;
    this.libraryPickerVisible = false;
    SessionStore.saveLibraryId(this.getAbilityContext(), library.id);
    this.loadVideos(true);
  }

  private openLibraryPicker(): void {
    this.libraryPickerVisible = true;
    this.loadLibraries();
  }

  @Builder
  private optionsPanel() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#99000000')
        .onClick(() => {
          this.optionsVisible = false;
        })

      Column({ space: 8 }) {
        Row() {
          Text('播放设置')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Blank()
          Text('关闭')
            .fontSize(13)
            .fontColor('#9DA3B2')
            .onClick(() => {
              this.optionsVisible = false;
            })
        }
        .width('100%')
        .padding({ bottom: 12 })

        Column({ space: 4 }) {
          Row({ space: 10 }) {
            Checkbox()
              .select(this.playMode() === 'shuffle')
              .selectedColor('#5B74F6')
              .onChange(() => this.togglePlayMode())
            Text('随机播放：打乱当前视频顺序')
              .fontSize(13)
              .fontColor('#B8BDCA')
          }
          .width('100%')
          .padding({ left: 6, right: 6, top: 10, bottom: 10 })

          Row({ space: 10 }) {
            Checkbox()
              .select(this.hideCollections)
              .selectedColor('#5B74F6')
              .onChange(() => this.toggleHideCollections())
            Text('隐藏合集与文件夹')
              .fontSize(13)
              .fontColor('#B8BDCA')
          }
          .width('100%')
          .padding({ left: 6, right: 6, top: 10, bottom: 10 })

          Row({ space: 10 }) {
            Checkbox()
              .select(this.rememberLogin)
              .selectedColor('#5B74F6')
              .onChange((value: boolean) => {
                this.rememberLogin = value;
                if (value) {
                  AppSettings.saveLogin(this.getAbilityContext(), this.serverUrl, this.userName, this.password);
                } else {
                  AppSettings.clearLogin(this.getAbilityContext());
                }
              })
            Text('记住服务器、用户名和密码')
              .fontSize(13)
              .fontColor('#B8BDCA')
          }
          .width('100%')
          .padding({ left: 6, right: 6, top: 10, bottom: 10 })
        }
        .width('100%')

        Column({ space: 8 }) {
          Text('长按屏幕加速倍速')
            .fontSize(13)
            .fontColor('#B8BDCA')
            .width('100%')
          Row({ space: 8 }) {
            ForEach(this.fastSpeedOptions(), (speed: number) => {
              Text(`${speed}x`)
                .fontSize(13)
                .fontColor(this.fastSpeed === speed ? Color.White : '#B8BDCA')
                .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                .borderRadius(14)
                .backgroundColor(this.fastSpeed === speed ? '#5B74F6' : '#1E2333')
                .onClick(() => {
                  this.fastSpeed = speed;
                  AppSettings.saveFastSpeed(this.getAbilityContext(), speed);
                })
            }, (speed: number) => `${speed}`)
          }
          .width('100%')
        }
        .width('100%')
        .margin({ top: 4 })

        Row({ space: 10 }) {
          Button('扫描媒体库')
            .layoutWeight(1)
            .height(44)
            .fontSize(13)
            .fontColor(Color.White)
            .backgroundColor('#2B2E39')
            .borderRadius(14)
            .onClick(() => this.refreshMediaLibrary())
          Button('更换服务器')
            .layoutWeight(1)
            .height(44)
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor('#2B2E39')
            .borderRadius(14)
            .onClick(() => this.changeServer())
          Button('关闭')
            .layoutWeight(1)
            .height(44)
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor('#5B74F6')
            .borderRadius(14)
            .onClick(() => {
              this.optionsVisible = false;
            })
        }
        .width('100%')
        .margin({ top: 14 })
      }
      .width('100%')
      .constraintSize({ maxWidth: 520 })
      .padding({ left: 20, right: 20, top: 22, bottom: 28 })
      .backgroundColor('#0E1017')
      .borderRadius({ topLeft: 24, topRight: 24 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private libraryPicker() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#99000000')
        .onClick(() => {
          this.libraryPickerVisible = false;
        })

      Column({ space: 8 }) {
        Row() {
          Text('选择媒体库')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Blank()
          Text('关闭')
            .fontSize(13)
            .fontColor('#9DA3B2')
            .onClick(() => {
              this.libraryPickerVisible = false;
            })
        }
        .width('100%')
        .padding({ bottom: 12 })

        if (this.libraries.length === 0) {
          Text('正在读取媒体库…')
            .fontSize(14)
            .fontColor('#9DA3B2')
            .padding({ top: 12, bottom: 12 })
        } else {
          Scroll() {
            Column({ space: 8 }) {
              ForEach(this.libraries, (library: EmbyLibrary) => {
                Row({ space: 10 }) {
                  Column({ space: 4 }) {
                    Text(library.name)
                      .fontSize(16)
                      .fontColor(library.id === this.selectedLibraryId ? '#7C9CFF' : Color.White)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(library.collectionType)
                      .fontSize(11)
                      .fontColor('#7A8091')
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  if (library.id === this.selectedLibraryId) {
                    Text('当前')
                      .fontSize(11)
                      .fontColor('#7C9CFF')
                  }
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                .borderRadius(14)
                .backgroundColor(library.id === this.selectedLibraryId ? '#1E2333' : '#141720')
                .onClick(() => this.selectLibrary(library))
              }, (library: EmbyLibrary) => library.id)
            }
            .width('100%')
          }
          .constraintSize({ maxHeight: 380 })
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: 520 })
      .padding({ left: 20, right: 20, top: 22, bottom: 28 })
      .backgroundColor('#0E1017')
      .borderRadius({ topLeft: 24, topRight: 24 })
    }
    .width('100%')
    .height('100%')
  }

  private connect(): void {
    if (this.serverUrl.trim().length === 0 || this.userName.trim().length === 0) {
      this.errorMessage = '请填写服务器地址和用户名';
      return;
    }
    this.connectAsync();
  }

  private async connectAsync(): Promise<void> {
    this.isConnecting = true;
    this.errorMessage = '';
    try {
      const loginClient = new EmbyClient(this.serverUrl, this.deviceId);
      const newSession = await loginClient.authenticate(this.userName, this.password);
      SessionStore.save(this.getAbilityContext(), newSession);
      this.session = newSession;
      this.serverUrl = newSession.serverUrl;
      this.userName = newSession.userName;
      this.password = '';
      this.client = new EmbyClient(newSession.serverUrl, this.deviceId, newSession.accessToken, newSession.userId);
      this.selectedLibraryId = SessionStore.loadLibraryId(this.getAbilityContext());
      if (this.rememberLogin) {
        AppSettings.saveLogin(this.getAbilityContext(), this.serverUrl, this.userName, this.password);
      } else {
        AppSettings.clearLogin(this.getAbilityContext());
      }
      this.loadLibraries();
      this.loadVideos(true);
    } catch (error) {
      this.errorMessage = this.describeError(error as Error);
    } finally {
      this.isConnecting = false;
    }
  }

  private async loadVideos(reset: boolean): Promise<void> {
    const client = this.client;
    if (client === null || this.isLoading) {
      return;
    }
    if (this.isFavoriteLibrary()) {
      if (reset) {
        this.videos = this.favorites.slice();
        this.totalRecordCount = this.favorites.length;
        this.hasMore = false;
        this.currentIndex = 0;
      }
      return;
    }
    if (this.isAuthorFiltered()) {
      this.isLoading = true;
      this.errorMessage = '';
      if (reset) {
        this.currentIndex = 0;
        this.videos = [];
        this.totalRecordCount = 0;
        this.hasMore = true;
        this.debugInfo = '';
        this.feedSourceCount = 0;
      }
      try {
        const author = this.filterAuthorName;
        const collected: Array<EmbyVideo> = [];
        const query = new EmbyVideoQuery();
        query.libraryId = '';
        query.hideCollections = this.hideCollections;
        let start = 0;
        let guard = 0;
        while (guard < 100) {
          const page: EmbyVideoPage = await client.getVideos(start, this.pageSize, query);
          const filtered = page.items.filter((video: EmbyVideo) => video.authorName === author);
          collected.push(...filtered);
          if (page.items.length === 0 || start + page.items.length >= page.totalRecordCount) {
            break;
          }
          start += page.items.length;
          guard++;
        }
        this.videos = collected;
        this.totalRecordCount = collected.length;
        this.hasMore = false;
        this.feedSourceCount = collected.length;
        if (collected.length === 0) {
          this.showHint('未找到该作者的其他视频');
        }
      } catch (error) {
        this.errorMessage = this.describeError(error as Error);
      } finally {
        this.isLoading = false;
        await this.flushReloadAfterDelete();
      }
      return;
    }
    this.isLoading = true;
    this.errorMessage = '';
    if (reset) {
      this.currentIndex = 0;
      this.videos = [];
      this.totalRecordCount = 0;
      this.hasMore = true;
      this.debugInfo = '';
      this.feedSourceCount = 0;
    }
    try {
      if (this.shufflePlayback && reset && !this.isFiltered()) {
        const all: Array<EmbyVideo> = await this.loadAllVideos();
        this.videos = this.shuffleList(all);
        this.totalRecordCount = all.length;
        this.hasMore = false;
        this.feedSourceCount = all.length;
      } else {
        const query = new EmbyVideoQuery();
        query.libraryId = this.selectedLibraryId;
        query.hideCollections = this.hideCollections;
        if (this.filterTagKind === 'genres') {
          query.genres = this.filterTagName;
        } else {
          query.tags = this.filterTagName;
        }
        const startIndex = reset ? 0 : this.feedSourceCount;
        const page: EmbyVideoPage = await client.getVideos(startIndex, this.pageSize, query);
        // 去重拼接：防止与局部刷新等路径交叠时产生重复 ID（ForEach key 重复会致渲染崩溃）
        const existing = new Set(this.videos.map((video: EmbyVideo) => video.id));
        const fresh = reset ? page.items : page.items.filter((video: EmbyVideo) => !existing.has(video.id));
        if (reset) {
          this.videos = page.items;
        } else {
          this.videos = this.videos.concat(fresh);
        }
        this.feedSourceCount = this.feedSourceCount + fresh.length;
        this.totalRecordCount = page.totalRecordCount;
        this.hasMore = this.videos.length < page.totalRecordCount && fresh.length > 0;
      }
      if (this.videos.length === 0) {
        const views: EmbyViewsSummary = await client.getViewsSummary();
        this.debugInfo = views.text;
      }
    } catch (error) {
      this.errorMessage = this.describeError(error as Error);
    } finally {
      this.isLoading = false;
      await this.flushReloadAfterDelete();
    }
  }

  private async flushReloadAfterDelete(): Promise<void> {
    if (!this.reloadAfterDelete) {
      return;
    }
    this.reloadAfterDelete = false;
    if (this.videos.length === 0) {
      await this.loadVideos(true);
    }
  }

  private shuffleList(source: Array<EmbyVideo>): Array<EmbyVideo> {
    const result: Array<EmbyVideo> = source.slice();
    for (let i: number = result.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const temp: EmbyVideo = result[i];
      result[i] = result[j];
      result[j] = temp;
    }
    return result;
  }

  private async loadAllVideos(): Promise<Array<EmbyVideo>> {
    const client = this.client;
    if (client === null) {
      return [];
    }
    const query = new EmbyVideoQuery();
    query.libraryId = this.selectedLibraryId;
    query.hideCollections = this.hideCollections;
    const all: Array<EmbyVideo> = [];
    let start = 0;
    let guard = 0;
    while (guard < 100) {
      const page: EmbyVideoPage = await client.getVideos(start, this.pageSize, query);
      all.push(...page.items);
      if (page.items.length === 0 || all.length >= page.totalRecordCount) {
        break;
      }
      start += page.items.length;
      guard++;
    }
    return all;
  }

  private libraryButtonLabel(): string {
    if (this.isTagFiltered()) {
      const tag = this.filterTagName.length > 5 ?
        `${this.filterTagName.substring(0, 5)}…` : this.filterTagName;
      return `#${tag}`;
    }
    if (this.isAuthorFiltered()) {
      const name = this.filterAuthorName.length > 5 ?
        `${this.filterAuthorName.substring(0, 5)}…` : this.filterAuthorName;
      return `@${name}`;
    }
    const name = this.selectedLibraryName.length > 6 ?
      `${this.selectedLibraryName.substring(0, 6)}…` : this.selectedLibraryName;
    return `库：${name}`;
  }

  private playMode(): string {
    return this.shufflePlayback ? 'shuffle' : 'off';
  }

  private fastSpeedOptions(): Array<number> {
    return [1.25, 1.5, 1.75, 2.0, 3.0];
  }

  private feedCounter(): string {
    const video = this.currentIndex >= 0 && this.currentIndex < this.videos.length
      ? this.videos[this.currentIndex] : null;
    if (this.shufflePlayback && video !== null && video.originalIndex > 0) {
      return `${video.originalIndex}/${this.totalRecordCount}`;
    }
    return `${this.currentIndex + 1}/${this.totalRecordCount}`;
  }

  private async openMediaList(): Promise<void> {
    this.multiSelectMode = false;
    this.selectedIds = [];
    this.mediaListVisible = true;
    this.mediaListItems = [];
    this.mediaListTotal = 0;
    this.mediaListHasMore = true;
    this.mediaListLoading = false;
    await this.loadMediaListPage();
    await this.scrollToCurrentMedia();
  }

  private async scrollToCurrentMedia(): Promise<void> {
    if (this.videos.length === 0 || this.currentIndex < 0 || this.currentIndex >= this.videos.length) {
      return;
    }
    const targetId = this.videos[this.currentIndex].id;
    let attempts = 0;
    while (this.mediaListHasMore && attempts < 50) {
      const index = this.mediaListItems.findIndex((video: EmbyVideo) => video.id === targetId);
      if (index >= 0) {
        this.scrollGridTo(index);
        return;
      }
      await this.loadMediaListPage();
      attempts++;
    }
    const index = this.mediaListItems.findIndex((video: EmbyVideo) => video.id === targetId);
    this.scrollGridTo(index >= 0 ? index : 0);
  }

  private scrollGridTo(index: number): void {
    if (this.mediaListItems.length === 0) {
      return;
    }
    const safeIndex = index < 0 ? 0 : index;
    setTimeout(() => {
      this.gridScroller.scrollToIndex(safeIndex, true, ScrollAlign.CENTER);
    }, 80);
  }

  private async loadMediaListPage(): Promise<void> {
    const client = this.client;
    if (client === null || this.mediaListLoading || !this.mediaListHasMore) {
      return;
    }
    if (this.isFavoriteLibrary()) {
      this.mediaListItems = this.favorites.slice();
      this.mediaListTotal = this.favorites.length;
      this.mediaListHasMore = false;
      return;
    }
    this.mediaListLoading = true;
    try {
      const query = new EmbyVideoQuery();
      query.libraryId = this.selectedLibraryId;
      query.hideCollections = this.hideCollections;
      const startIndex = this.mediaListItems.length;
      const page: EmbyVideoPage = await client.getVideos(startIndex, this.pageSize, query);
      const existing = new Set(this.mediaListItems.map((item: EmbyVideo) => item.id));
      const fresh = page.items.filter((item: EmbyVideo) => !existing.has(item.id));
      this.mediaListItems = this.mediaListItems.concat(fresh);
      this.mediaListTotal = page.totalRecordCount;
      this.mediaListHasMore = this.mediaListItems.length < page.totalRecordCount && fresh.length > 0;
    } catch (error) {
      this.errorMessage = this.describeError(error as Error);
    } finally {
      this.mediaListLoading = false;
    }
  }

  private playFromList(item: EmbyVideo): void {
    this.multiSelectMode = false;
    this.selectedIds = [];
    this.mediaListVisible = false;
    const index = this.videos.findIndex((video: EmbyVideo) => video.id === item.id);
    if (index >= 0) {
      this.currentIndex = index;
      this.swiperController.changeIndex(index, false);
      return;
    }
    this.videos.unshift(item);
    this.currentIndex = 0;
    this.swiperController.changeIndex(0, false);
  }

  private togglePlayMode(): void {
    this.shufflePlayback = !this.shufflePlayback;
    AppSettings.saveShuffle(this.getAbilityContext(), this.shufflePlayback);
    this.loadVideos(true);
  }

  private handlePlaybackEnd(): void {
    if (this.videos.length === 0) {
      return;
    }
    const isLast: boolean = this.currentIndex >= this.videos.length - 1;
    if (isLast && this.shufflePlayback) {
      this.videos = this.shuffleList(this.videos);
      this.currentIndex = 0;
      this.swiperController.changeIndex(0, false);
      this.showHint('没有更多视频，已重新随机');
      return;
    }
    if (isLast && this.hasMore) {
      this.loadVideos(false);
      return;
    }
    if (isLast) {
      this.showHint('已经是最后一个视频');
      return;
    }
    this.swiperController.changeIndex(this.currentIndex + 1, true);
  }

  private toggleHideCollections(): void {
    this.hideCollections = !this.hideCollections;
    AppSettings.saveHideCollections(this.getAbilityContext(), this.hideCollections);
    this.loadVideos(true);
  }

  private async refreshMediaLibrary(): Promise<void> {
    if (this.isLoading || this.mediaListLoading) {
      this.showHint('正在加载中，请稍候');
      return;
    }
    const client = this.client;
    if (client === null) {
      this.showHint('尚未连接服务器');
      return;
    }
    if (this.isFavoriteLibrary()) {
      this.showHint('「喜欢」是本地收藏，无需扫描');
      return;
    }
    this.optionsVisible = false;
    this.showHint('正在通知服务器扫描媒体库…');
    try {
      if (this.selectedLibraryId.length > 0) {
        await client.refreshItem(this.selectedLibraryId);
      } else {
        // 未指定媒体库（全部媒体/作者筛选）：逐个扫描服务器上的真实媒体库
        for (const library of this.libraries) {
          if (library.id === 'favorites') {
            continue;
          }
          await client.refreshItem(library.id);
        }
      }
    } catch (error) {
      this.showHint(`扫描失败：${this.describeError(error as Error)}`);
      return;
    }
    // Emby 扫描为服务端后台任务，耗时取决于库大小，交由服务器自行完成
    this.showHint('媒体库扫描已开始，新内容稍后自动可见');
  }

  private describeError(error: Error): string {
    if (error && error.message) {
      if (error.message.includes('2300997')) {
        return '系统已阻止明文 HTTP，请为 Emby 配置 HTTPS 后重试';
      }
      return error.message;
    }
    return '连接失败，请检查服务器地址和网络';
  }

  private changeServer(): void {
    SessionStore.clear(this.getAbilityContext());
    this.session = null;
    this.client = null;
    this.videos = [];
    this.currentIndex = 0;
    this.totalRecordCount = 0;
    this.errorMessage = '';
    this.debugInfo = '';
    this.libraries = [];
    this.selectedLibraryId = '';
    this.selectedLibraryName = '全部媒体库';
    this.libraryPickerVisible = false;
    this.optionsVisible = false;
    this.controlsHidden = false;
  }

  @Builder
  private loginPage() {
    Scroll() {
      Column() {
        Column({ space: 12 }) {
          Text('EMDY')
            .fontSize(44)
            .fontWeight(FontWeight.Bold)
            .fontColor('#7C9CFF')
            .letterSpacing(5)
          Text('你的 Emby 短视频流')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
          Text('连接私人媒体库，上下滑动连续观看')
            .fontSize(14)
            .fontColor('#8F94A3')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .margin({ bottom: 48 })

        Column({ space: 18 }) {
          Column({ space: 8 }) {
            Text('服务器地址')
              .fontSize(13)
              .fontColor('#B8BDCA')
              .width('100%')
            TextInput({ placeholder: 'https://emby.example.com', text: this.serverUrl })
              .height(54)
              .fontSize(16)
              .fontColor(Color.White)
              .placeholderColor('#666C7A')
              .backgroundColor('#171922')
              .borderRadius(14)
              .padding({ left: 16, right: 16 })
              .onChange((value: string) => {
                this.serverUrl = value;
              })
          }
          .width('100%')

          Column({ space: 8 }) {
            Text('用户名')
              .fontSize(13)
              .fontColor('#B8BDCA')
              .width('100%')
            TextInput({ placeholder: 'Emby 用户名', text: this.userName })
              .height(54)
              .fontSize(16)
              .fontColor(Color.White)
              .placeholderColor('#666C7A')
              .backgroundColor('#171922')
              .borderRadius(14)
              .padding({ left: 16, right: 16 })
              .onChange((value: string) => {
                this.userName = value;
              })
          }
          .width('100%')

          Column({ space: 8 }) {
            Text('密码')
              .fontSize(13)
              .fontColor('#B8BDCA')
              .width('100%')
            TextInput({ placeholder: '可留空', text: this.password })
              .type(InputType.Password)
              .height(54)
              .fontSize(16)
              .fontColor(Color.White)
              .placeholderColor('#666C7A')
              .backgroundColor('#171922')
              .borderRadius(14)
              .padding({ left: 16, right: 16 })
              .onChange((value: string) => {
                this.password = value;
              })
          }
          .width('100%')
        }
        .width('100%')

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(13)
            .fontColor('#FF8A8A')
            .width('100%')
            .margin({ top: 18 })
        }

        Column({ space: 10 }) {
          Row({ space: 10 }) {
            Checkbox()
              .select(this.rememberLogin)
              .selectedColor('#5B74F6')
              .onChange((value: boolean) => {
                this.rememberLogin = value;
              })
            Text('记住服务器、用户名和密码')
              .fontSize(13)
              .fontColor('#B8BDCA')
          }
          .width('100%')

          Row({ space: 10 }) {
            Checkbox()
              .select(this.hideCollections)
              .selectedColor('#5B74F6')
              .onChange((value: boolean) => {
                this.hideCollections = value;
                AppSettings.saveHideCollections(this.getAbilityContext(), value);
              })
            Text('隐藏媒体库里的合集与文件夹')
              .fontSize(13)
              .fontColor('#B8BDCA')
          }
          .width('100%')
        }
        .width('100%')
        .margin({ top: 20 })

        Button(this.isConnecting ? '正在连接…' : '连接并开始')
          .width('100%')
          .height(54)
          .margin({ top: 28 })
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor(this.isConnecting ? '#434B67' : '#5B74F6')
          .borderRadius(16)
          .enabled(!this.isConnecting)
          .onClick(() => this.connect())

        Text(this.rememberLogin ? '登录令牌、服务器、用户名与密码会保存在本机。建议优先使用 HTTPS。' :
          '登录令牌会保存在本机，密码不会保存。建议优先使用 HTTPS。')
          .fontSize(12)
          .fontColor('#666C7A')
          .textAlign(TextAlign.Center)
          .lineHeight(18)
          .margin({ top: 18 })
      }
      .width('100%')
      .constraintSize({ maxWidth: 520 })
      .padding({ left: 28, right: 28, top: this.topInset() + 40, bottom: this.bottomInset() })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#090A0F')
  }

  private restoreInset(): number {
    return this.bottomSafePadding > 0 ? this.bottomSafePadding + 12 : 28;
  }

  private drawRestoreEye(): void {
    const ctx = this.restoreEyeCanvas;
    if (ctx.width <= 0) {
      return;
    }
    ctx.clearRect(0, 0, ctx.width, ctx.height);
    const s = ctx.width / 28;
    ctx.save();
    ctx.scale(s, s);
    ctx.strokeStyle = '#FFFFFF';
    ctx.fillStyle = '#FFFFFF';
    ctx.lineWidth = 2.2;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    const cx = 14;
    const cy = 14;
    const rx = 11;
    const ry = 7;
    ctx.beginPath();
    ctx.ellipse(cx, cy, rx, ry, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(cx, cy, ry * 0.85, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  private showHint(message: string): void {
    if (this.hintTimer !== 0) {
      clearTimeout(this.hintTimer);
      this.hintTimer = 0;
    }
    this.hintText = message;
    this.hintTimer = setTimeout(() => {
      this.hintText = '';
      this.hintTimer = 0;
    }, 1600);
  }

  @Builder
  private feedPage() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.videos.length > 0) {
        Swiper(this.swiperController) {
          ForEach(this.videos, (item: EmbyVideo, index: number) => {
            ShortVideoCard({
              item: item,
              active: index === this.currentIndex,
              muted: this.muted,
              bottomSafePadding: this.bottomSafePadding,
              playMode: this.playMode(),
              immersive: this.immersive,
              controlsHidden: this.controlsHidden,
              fastSpeed: this.fastSpeed,
              onTogglePlayMode: (hint: string) => {
                this.togglePlayMode();
                this.showHint(hint);
              },
              onToggleImmersive: (hint: string) => {
                this.toggleImmersive();
                this.showHint(hint);
              },
              onToggleMute: (hint: string) => {
                this.muted = !this.muted;
                this.showHint(hint);
              },
              onHideControls: () => {
                this.controlsHidden = true;
                this.showHint('已隐藏所有按钮');
              },
              onPlaybackEnd: () => this.handlePlaybackEnd(),
              onToggleFavorite: (item: EmbyVideo) => this.toggleFavorite(item),
              onOpenAuthor: (item: EmbyVideo) => this.openAuthorFeed(item),
              onFilterTag: (tag: string, kind: string) => this.openTagFeed(tag, kind),
              onDeleteVideo: (item: EmbyVideo) => this.confirmDeleteVideo(item),
              deletePending: this.deletePending,
              isFavorite: this.isFavoriteVideo(item)
            })
          }, (item: EmbyVideo) => item.id)
        }
        .index(this.currentIndex)
        .vertical(true)
        .loop(false)
        .indicator(false)
        .cachedCount(1)
        .duration(260)
        .enabled(!this.deletePending)
        .onChange((index: number) => {
          this.currentIndex = index;
          if (this.hasMore && index >= this.videos.length - 3) {
            this.loadVideos(false);
          }
        })
        .width('100%')
        .height('100%')
      } else if (this.isLoading) {
        Column({ space: 16 }) {
          LoadingProgress()
            .width(42)
            .height(42)
            .color('#7C9CFF')
          Text('正在读取媒体库…')
            .fontSize(14)
            .fontColor('#B8BDCA')
        }
      } else {
        Column({ space: 14 }) {
          Text('没有找到视频')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Text('当前用户至少有一个媒体库，但没有取到视频条目。')
            .fontSize(14)
            .fontColor('#9DA3B2')
            .textAlign(TextAlign.Center)
            .lineHeight(21)
          if (this.debugInfo.length > 0) {
            Text(`可见媒体库：${this.debugInfo}`)
              .fontSize(12)
              .fontColor('#7C9CFF')
              .textAlign(TextAlign.Center)
              .lineHeight(18)
          }
          Row({ space: 12 }) {
            Button('重试')
              .fontColor(Color.White)
              .backgroundColor('#5B74F6')
              .onClick(() => this.loadVideos(true))
            Button('更换服务器')
              .fontColor(Color.White)
              .backgroundColor('#2B2E39')
              .onClick(() => this.changeServer())
          }
        }
        .padding(28)
      }

      if (!this.controlsHidden) {
      Row({ space: 8 }) {
        Scroll() {
          Row({ space: 8 }) {
            Button(this.libraryButtonLabel())
              .height(34)
              .fontSize(12)
              .fontColor(Color.White)
              .backgroundColor('#66000000')
              .borderRadius(17)
              .padding({ left: 12, right: 12 })
              .onClick(() => this.openLibraryPicker())
            Button('设置')
              .height(34)
              .fontSize(12)
              .fontColor(Color.White)
              .backgroundColor('#66000000')
              .borderRadius(17)
              .padding({ left: 12, right: 12 })
              .onClick(() => {
                this.optionsVisible = true;
              })
          }
          .height('100%')
          .constraintSize({ minWidth: '100%' })
        }
        .layoutWeight(1)
        .height(34)
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .margin({ right: 8 })

        if (this.videos.length > 0) {
          Text(this.feedCounter())
            .fontSize(12)
            .fontColor('#D9FFFFFF')
        }
        if (this.isFiltered()) {
          Button('全部视频')
            .height(34)
            .fontSize(12)
            .fontColor(Color.White)
            .backgroundColor('#5B74F6')
            .borderRadius(17)
            .padding({ left: 12, right: 12 })
            .onClick(() => this.clearFilter())
        } else {
          Button('全部媒体')
            .height(34)
            .fontSize(12)
            .fontColor(Color.White)
            .backgroundColor('#66000000')
            .borderRadius(17)
            .padding({ left: 12, right: 12 })
            .onClick(() => this.openMediaList())
        }
      }
      .width('100%')
      .constraintSize({ minHeight: 46 })
      .padding({
        left: 14,
        right: 14,
        top: this.topInset(),
        bottom: 6
      })
      }

      if (this.controlsHidden) {
        Column() {
          Column() {
            Canvas(this.restoreEyeCanvas)
              .width(28)
              .height(28)
              .onReady(() => {
                this.drawRestoreEye();
              })
          }
          .width(48)
          .height(48)
          .justifyContent(FlexAlign.Center)
          .borderRadius(24)
          .backgroundColor('#66000000')
          .margin({ right: 16, bottom: this.restoreInset() })
          .onClick(() => {
            this.controlsHidden = false;
            this.showHint('已显示全部按钮');
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
        .alignItems(HorizontalAlign.End)
        .hitTestBehavior(HitTestMode.Transparent)
      }

      if (this.hintText.length > 0) {
        Column() {
          Text(this.hintText)
            .fontSize(14)
            .fontColor(Color.White)
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .borderRadius(20)
            .backgroundColor('#B3000000')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .hitTestBehavior(HitTestMode.Transparent)
      }

      if (this.isLoading && this.videos.length > 0) {
        LoadingProgress()
          .width(28)
          .height(28)
          .color(Color.White)
          .align(Alignment.Bottom)
          .margin({ bottom: 12 })
      }

      if (this.libraryPickerVisible) {
        this.libraryPicker()
      }

      if (this.optionsVisible) {
        this.optionsPanel()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }

  private isCurrentPlaying(item: EmbyVideo): boolean {
    if (this.videos.length === 0 || this.currentIndex < 0 || this.currentIndex >= this.videos.length) {
      return false;
    }
    return this.videos[this.currentIndex].id === item.id;
  }

  @Builder
  private mediaGridItem(item: EmbyVideo) {
    Column({ space: 6 }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Image(item.imageUrl)
          .width('100%')
          .aspectRatio(9 / 16)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
          .alt($r('app.media.startIcon'))
        if (item.durationText.length > 0) {
          Text(item.durationText)
            .fontSize(10)
            .fontColor(Color.White)
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .backgroundColor('#99000000')
            .borderRadius(4)
            .margin({ right: 4, bottom: 4 })
        }
        if (this.isFavoriteVideo(item)) {
          Text('♥')
            .fontSize(11)
            .fontColor('#FF5E7A')
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .backgroundColor('#99000000')
            .borderRadius(4)
            .margin({ left: 4, bottom: 4 })
        }
        if (this.isCurrentPlaying(item)) {
          Row({ space: 4 }) {
            Text('▶')
              .fontSize(9)
              .fontColor(Color.White)
            Text('播放中')
              .fontSize(10)
              .fontColor(Color.White)
          }
          .padding({ left: 6, right: 6, top: 3, bottom: 3 })
          .backgroundColor('#5B74F6')
          .borderRadius(4)
          .margin({ left: 4, top: 4 })
          .align(Alignment.TopStart)
        }
        if (this.multiSelectMode && this.selectedIds.includes(item.id)) {
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor('#595B74F6')
          Stack({ alignContent: Alignment.Center }) {
            Text('✓')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
          .width(24)
          .height(24)
          .borderRadius(12)
          .backgroundColor('#5B74F6')
          .margin({ top: 6, right: 6 })
          .align(Alignment.TopEnd)
        }
      }
      .width('100%')
      .aspectRatio(9 / 16)
      .border(this.isCurrentPlaying(item) ? { width: 2, color: '#5B74F6' } : { width: 0 })

      Text(item.name)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.isCurrentPlaying(item) ? '#7C9CFF' : Color.White)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('100%')
    .gesture(
      LongPressGesture({ repeat: false, duration: 400 })
        .onAction(() => this.enterMultiSelect(item))
    )
    .onClick(() => {
      if (this.multiSelectMode) {
        if (Date.now() - this.lastLongPressTime > 300) {
          this.toggleSelect(item);
        }
        return;
      }
      this.playFromList(item);
    })
  }

  @Builder
  private mediaListPage() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#090A0F')

      Column() {
        Column() {
        if (this.multiSelectMode) {
          Row({ space: 10 }) {
            Text('取消')
              .fontSize(13)
              .fontColor('#9DA3B2')
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor('#2B2E39')
              .borderRadius(14)
              .onClick(() => this.exitMultiSelect())
            Text(`已选 ${this.selectedIds.length}`)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .layoutWeight(1)
              .margin({ left: 4 })
              .maxLines(1)
            Text(this.selectedIds.length >= this.mediaListItems.length && this.mediaListItems.length > 0
              ? '取消全选' : '全选')
              .fontSize(13)
              .fontColor('#7C9CFF')
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor('#1E2A4A')
              .borderRadius(14)
              .onClick(() => this.toggleSelectAll())
            Text(this.selectedIds.length > 0 ? `删除(${this.selectedIds.length})` : '删除')
              .fontSize(13)
              .fontColor(this.selectedIds.length > 0 && !this.batchDeletePending ? '#FF5E7A' : '#667080')
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor('#3A2028')
              .borderRadius(14)
              .onClick(() => this.confirmBatchDelete())
          }
        } else {
          Row() {
            Text(this.selectedLibraryName)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            Text(this.mediaListTotal > 0 ? `共 ${this.mediaListTotal} 个视频` : '')
              .fontSize(12)
              .fontColor('#9DA3B2')
              .margin({ right: 14 })
            Text('关闭')
              .fontSize(13)
              .fontColor('#9DA3B2')
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor('#2B2E39')
              .borderRadius(14)
              .onClick(() => {
                this.mediaListVisible = false;
              })
          }
        }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })

        Grid(this.gridScroller) {
          ForEach(this.mediaListItems, (item: EmbyVideo) => {
            GridItem() {
              this.mediaGridItem(item)
            }
          }, (item: EmbyVideo) => item.id)
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(8)
        .rowsGap(14)
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 12, right: 12 })
        .scrollBar(BarState.Off)
        .onScrollIndex((_start: number, end: number) => {
          if (end >= this.mediaListItems.length - 6) {
            this.loadMediaListPage();
          }
        })
        .onReachEnd(() => {
          this.loadMediaListPage();
        })

        if (this.mediaListLoading) {
          Row({ space: 10 }) {
            LoadingProgress()
              .width(20)
              .height(20)
              .color('#7C9CFF')
            Text('正在加载更多…')
              .fontSize(12)
              .fontColor('#9DA3B2')
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 12, bottom: 12 })
        } else if (!this.mediaListHasMore && this.mediaListItems.length > 0) {
          Text('已加载全部视频')
            .fontSize(12)
            .fontColor('#9DA3B2')
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 12 })
        }
      }
      .width('100%')
      .height('100%')
      .padding({
        top: this.topInset(),
        bottom: this.bottomSafePadding > 0 ? this.bottomSafePadding : 12
      })

      if (this.mediaListItems.length === 0 && !this.mediaListLoading) {
        Column({ space: 12 }) {
          Text('暂无视频')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Text('当前媒体库没有可显示的视频条目。')
            .fontSize(13)
            .fontColor('#9DA3B2')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#090A0F')
    .transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseOut }))
  }

  onBackPress(): boolean {
    if (this.multiSelectMode) {
      this.exitMultiSelect();
      return true;
    }
    if (this.mediaListVisible) {
      this.mediaListVisible = false;
      return true;
    }
    return false;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.session === null) {
        this.loginPage()
      } else if (this.mediaListVisible) {
        this.mediaListPage()
      } else {
        this.feedPage()
      }
      this.deleteConfirmDialog()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private deleteConfirmDialog() {
    Stack() {
      Column({ space: 16 }) {
        Text('删除视频')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
        Text(this.deleteConfirmMode === 'batch' ?
          `确定删除选中的 ${this.selectedIds.length} 个视频吗？将从 Emby 服务器永久移除，不可恢复。` :
          `确定删除《${this.deleteConfirmTitle}》吗？将从 Emby 服务器永久移除，不可恢复。`)
          .fontSize(13)
          .fontColor('#B8FFFFFF')
          .textAlign(TextAlign.Center)
        Row({ space: 12 }) {
          Button('取消')
            .flexGrow(1)
            .fontSize(14)
            .fontColor('#A9B0C0')
            .backgroundColor('#2B2E39')
            .borderRadius(18)
            .onClick(() => {
              this.deleteConfirmVisible = false;
            })
          Button('删除')
            .flexGrow(1)
            .fontSize(14)
            .fontColor('#FF3B30')
            .backgroundColor('#3A2028')
            .borderRadius(18)
            .onClick(() => {
              this.deleteConfirmVisible = false;
              if (this.deleteConfirmMode === 'batch') {
                this.batchDeleteSelected();
              } else {
                this.deleteCurrentVideo(this.deleteConfirmItem);
              }
            })
        }
      }
      .padding(24)
      .backgroundColor('#1E2230')
      .borderRadius(20)
      .width('84%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#99000000')
    .visibility(this.deleteConfirmVisible ? Visibility.Visible : Visibility.None)
    .onClick(() => {
      if (!this.deletePending) {
        this.deleteConfirmVisible = false;
      }
    })
  }
}
