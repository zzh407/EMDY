import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppSettings } from '../service/AppSettings';
import { EmbyClient, EmbyVideoQuery } from '../service/EmbyClient';
import { SessionStore } from '../service/SessionStore';
import { EmbyLibrary, EmbyPlaybackMode, EmbySession, EmbyVideo, EmbyVideoPage, EmbyViewsSummary } from '../model/EmbyModels';

@Component
struct ShortVideoCard {
  @Prop item: EmbyVideo = new EmbyVideo();
  @Prop @Watch('onActiveChanged') active: boolean = false;
  @Prop muted: boolean = false;
  @Prop bottomSafePadding: number = 0;
  @Prop playMode: string = 'off';
  @Prop immersive: boolean = true;
  @Prop controlsHidden: boolean = false;
  onTogglePlayMode: (hint: string) => void = () => {};
  onToggleImmersive: (hint: string) => void = () => {};
  onHideControls: () => void = () => {};
  onPlaybackEnd: () => void = () => {};
  @State isPlaying: boolean = false;
  @State hasStarted: boolean = false;
  @State hasError: boolean = false;
  @State modeIndex: number = 0;
  @State currentSrc: string = '';
  private controller: VideoController = new VideoController();
  private lastItemId: string = '';


  private resolveSource(item: EmbyVideo, modeIndex: number): string {
    const modes: Array<EmbyPlaybackMode> = item.playbackModes.length > 0 ? item.playbackModes : ['direct'];
    const safeIndex = modeIndex < modes.length ? modeIndex : 0;
    return item.urlOf(modes[safeIndex]);
  }

  private syncSource(): void {
    const nextSrc = this.resolveSource(this.item, this.modeIndex);
    if (nextSrc.length === 0) {
      return;
    }
    this.currentSrc = nextSrc;
  }

  aboutToAppear(): void {
    this.lastItemId = this.item.id;
    this.syncSource();
  }

  private tryNextMode(): void {
    const modes: Array<EmbyPlaybackMode> = this.item.playbackModes.length > 0 ?
      this.item.playbackModes : ['direct'];
    this.modeIndex = (this.modeIndex + 1) % modes.length;
    this.hasError = false;
    this.controller.stop();
    this.syncSource();
    if (this.active) {
      this.controller.start();
    }
  }

  private retryCurrent(): void {
    this.hasError = false;
    this.controller.stop();
    this.syncSource();
    if (this.active) {
      this.controller.start();
    }
  }

  private onActiveChanged(): void {
    if (this.lastItemId !== this.item.id) {
      this.lastItemId = this.item.id;
      this.modeIndex = 0;
      this.syncSource();
    }
    if (this.active) {
      this.hasStarted = false;
      this.controller.start();
    } else {
      this.controller.pause();
      this.controller.setCurrentTime(0);
      this.isPlaying = false;
      this.hasStarted = false;
    }
  }

  private togglePlayback(): void {
    if (this.isPlaying) {
      this.controller.pause();
    } else {
      this.controller.start();
    }
  }

  @Builder
  private itemCaption(padding: number) {
    if (!this.controlsHidden && (this.item.name.length > 0 || this.item.authorName.length > 0 ||
      this.item.overview.length > 0)) {
      Row({ space: 12 }) {
        if (this.item.authorAvatar.length > 0) {
          Image(this.item.authorAvatar)
            .width(46)
            .height(46)
            .borderRadius(23)
            .objectFit(ImageFit.Cover)
            .alt($r('app.media.startIcon'))
        } else {
          Stack({ alignContent: Alignment.Center }) {
            Text(this.item.authorInitial())
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
          .width(46)
          .height(46)
          .borderRadius(23)
          .backgroundColor('#2A2F3D')
        }

        Column({ space: 6 }) {
          Text(this.item.authorName.length > 0 ? `@${this.item.authorName}` : '未标注作者')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          if (this.item.name.length > 0) {
            Row({ space: 8 }) {
              Text(this.item.name)
                .fontSize(17)
                .fontWeight(FontWeight.Medium)
                .fontColor('#F2F5FF')
                .maxLines(3)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
              if (this.item.durationText.length > 0) {
                Text(this.item.durationText)
                  .fontSize(12)
                  .fontColor(Color.White)
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .backgroundColor('#66000000')
                  .borderRadius(8)
              }
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          }
          if (this.item.overview.length > 0) {
            Text(this.item.overview)
              .fontSize(14)
              .fontColor('#D9FFFFFF')
              .maxLines(6)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
      .padding({ left: 18, right: 24, bottom: this.captionBottom(padding), top: 56 })
      .linearGradient({
        angle: 180,
        colors: [['#00000000', 0], ['#66000000', 0.5], ['#CC000000', 1]]
      })
      .hitTestBehavior(HitTestMode.Transparent)
    }
  }

  private captionBottom(bottomPadding: number): number {
    return bottomPadding > 0 ? bottomPadding + 12 : 28;
  }

  private playModeActive(): boolean {
    return this.playMode === 'shuffle';
  }

  private playModeHint(): string {
    return this.playMode === 'shuffle' ? '播放模式：随机播放' : '播放模式：顺序播放';
  }

  @Builder
  private playModeIcon() {
    if (this.playMode === 'shuffle') {
      Text('⇄')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.playModeActive() ? Color.White : '#A9B0C0')
    } else {
      Text('→')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.playModeActive() ? Color.White : '#A9B0C0')
    }
  }

  @Builder
  private eyeIcon(open: boolean, pupilColor: ResourceColor) {
    Stack({ alignContent: Alignment.Center }) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(26)
          .height(18)
          .borderRadius(13)
          .backgroundColor(Color.White)
        Column()
          .width(20)
          .height(12)
          .borderRadius(10)
          .backgroundColor(pupilColor)
      }
      .width(26)
      .height(18)

      if (open) {
        Column()
          .width(9)
          .height(9)
          .borderRadius(5)
          .backgroundColor(Color.White)
      } else {
        Column()
          .width(26)
          .height(2)
          .borderRadius(1)
          .backgroundColor(Color.White)
          .rotate({ angle: -32 })
      }
    }
    .width(30)
    .height(30)
  }

  private nextModeLabel(): string {
    const modes: Array<EmbyPlaybackMode> = this.item.playbackModes.length > 0 ?
      this.item.playbackModes : ['direct'];
    const nextIndex = (this.modeIndex + 1) % modes.length;
    return `兼容模式：${this.item.labelOf(modes[nextIndex])}`;
  }

  aboutToDisappear(): void {
    this.controller.stop();
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Image(this.item.imageUrl)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .opacity(0.28)
        .blur(36)

      Video({
        src: this.currentSrc,
        previewUri: this.item.imageUrl,
        controller: this.controller
      })
        .width('100%')
        .height('100%')
        .objectFit(this.item.isPortrait() ? ImageFit.Cover : ImageFit.Contain)
        .autoPlay(this.active)
        .muted(this.muted)
        .controls(false)
        .loop(false)
        .onStart(() => {
          this.isPlaying = true;
          this.hasStarted = true;
          this.hasError = false;
        })
        .onPause(() => {
          this.isPlaying = false;
        })
        .onFinish(() => {
          this.isPlaying = false;
          this.onPlaybackEnd();
        })
        .onError(() => {
          this.isPlaying = false;
          this.hasError = true;
        })
        .onClick(() => this.togglePlayback())

      if (this.active && !this.isPlaying && this.hasStarted && !this.hasError) {
        Button('播放')
          .fontSize(16)
          .fontColor(Color.White)
          .backgroundColor('#66000000')
          .borderRadius(28)
          .width(72)
          .height(56)
          .onClick(() => this.togglePlayback())
      }

      if (this.hasError) {
        Column({ space: 12 }) {
          Text('视频播放失败')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
          Text('当前编码可能不支持直播放，可切换兼容模式播放')
            .fontSize(13)
            .fontColor('#B8FFFFFF')
          Row({ space: 12 }) {
            Button(this.nextModeLabel())
              .fontColor(Color.White)
              .backgroundColor('#5B74F6')
              .borderRadius(18)
              .onClick(() => this.tryNextMode())
            Button('重试')
              .fontColor(Color.White)
              .backgroundColor('#2B2E39')
              .borderRadius(18)
              .onClick(() => this.retryCurrent())
          }
        }
        .padding(24)
        .backgroundColor('#99000000')
        .borderRadius(20)
      }

      Column() {
        Blank()
        this.itemCaption(this.bottomSafePadding)
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.Transparent)

      if (!this.controlsHidden) {
        Column() {
          Column({ space: 14 }) {
            Column() {
              this.playModeIcon()
            }
            .width(48)
            .height(48)
            .justifyContent(FlexAlign.Center)
            .borderRadius(24)
            .backgroundColor(this.playModeActive() ? '#5B74F6' : '#66000000')
            .onClick(() => this.onTogglePlayMode(this.playModeHint()))

            Column() {
              Text(this.immersive ? '⛶' : '⛝')
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.immersive ? Color.White : '#A9B0C0')
            }
            .width(48)
            .height(48)
            .justifyContent(FlexAlign.Center)
            .borderRadius(24)
            .backgroundColor(this.immersive ? '#5B74F6' : '#66000000')
            .onClick(() => this.onToggleImmersive(this.immersive ? '已退出全屏' : '已切换为全屏'))

            Column() {
              this.eyeIcon(false, '#12141A')
            }
            .width(48)
            .height(48)
            .justifyContent(FlexAlign.Center)
            .borderRadius(24)
            .backgroundColor('#66000000')
            .onClick(() => this.onHideControls())
          }
          .alignItems(HorizontalAlign.Center)
          .margin({ right: 16 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.End)
        .hitTestBehavior(HitTestMode.Transparent)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}

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
  @State loopPlayback: boolean = true;
  @State shufflePlayback: boolean = false;
  @State optionsVisible: boolean = false;
  @State topSafePadding: number = 0;
  @State bottomSafePadding: number = 0;
  @State immersive: boolean = true;
  @State controlsHidden: boolean = false;
  @State hintText: string = '';
  private deviceId: string = '';
  private client: EmbyClient | null = null;
  private hintTimer: number = 0;
  private swiperController: SwiperController = new SwiperController();

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
    const playbackOptions: Array<boolean> = AppSettings.loadPlaybackOptions(context);
    this.loopPlayback = playbackOptions[0];
    this.shufflePlayback = playbackOptions[1];
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
      this.libraries = libraries;
      this.applyLibrarySelection(libraries, this.selectedLibraryId);
    } catch (error) {
      this.libraries = [new EmbyLibrary('', '全部媒体库', 'all')];
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

  private selectLibrary(library: EmbyLibrary): void {
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

        Row({ space: 10 }) {
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
    this.isLoading = true;
    this.errorMessage = '';
    if (reset) {
      this.currentIndex = 0;
      this.videos = [];
      this.totalRecordCount = 0;
      this.hasMore = true;
      this.debugInfo = '';
    }
    try {
      const query = new EmbyVideoQuery();
      query.libraryId = this.selectedLibraryId;
      query.hideCollections = this.hideCollections;
      const startIndex = reset ? 0 : this.videos.length;
      const page: EmbyVideoPage = await client.getVideos(startIndex, this.pageSize, query);
      const merged: Array<EmbyVideo> = reset ? page.items : this.videos.concat(page.items);
      this.videos = this.shufflePlayback ? this.shuffleList(merged) : merged;
      this.totalRecordCount = page.totalRecordCount;
      this.hasMore = this.videos.length < page.totalRecordCount && page.items.length > 0;
      if (this.videos.length === 0) {
        const views: EmbyViewsSummary = await client.getViewsSummary();
        this.debugInfo = views.text;
      }
    } catch (error) {
      this.errorMessage = this.describeError(error as Error);
    } finally {
      this.isLoading = false;
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

  private libraryButtonLabel(): string {
    const name = this.selectedLibraryName.length > 6 ?
      `${this.selectedLibraryName.substring(0, 6)}…` : this.selectedLibraryName;
    return `库：${name}`;
  }

  private playMode(): string {
    return this.shufflePlayback ? 'shuffle' : 'off';
  }

  private togglePlayMode(): void {
    this.shufflePlayback = !this.shufflePlayback;
    this.loopPlayback = false;
    AppSettings.savePlaybackOptions(this.getAbilityContext(), this.loopPlayback, this.shufflePlayback);
    this.loadVideos(true);
  }

  private handlePlaybackEnd(): void {
    if (this.videos.length === 0) {
      return;
    }
    const isLast: boolean = this.currentIndex >= this.videos.length - 1;
    if (isLast && this.hasMore) {
      this.loadVideos(false);
      return;
    }
    if (isLast && this.shufflePlayback) {
      this.loadVideos(true);
      this.showHint('没有更多视频，已重新随机');
      return;
    }
    if (isLast) {
      this.showHint('已经是最后一个视频');
      return;
    }
    this.currentIndex = this.currentIndex + 1;
    this.swiperController.changeIndex(this.currentIndex, true);
  }

  private toggleHideCollections(): void {
    this.hideCollections = !this.hideCollections;
    AppSettings.saveHideCollections(this.getAbilityContext(), this.hideCollections);
    this.loadVideos(true);
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
              onTogglePlayMode: (hint: string) => {
                this.togglePlayMode();
                this.showHint(hint);
              },
              onToggleImmersive: (hint: string) => {
                this.toggleImmersive();
                this.showHint(hint);
              },
              onHideControls: () => {
                this.controlsHidden = true;
                this.showHint('已隐藏所有按钮');
              },
              onPlaybackEnd: () => this.handlePlaybackEnd()
            })
          }, (item: EmbyVideo) => item.id)
        }
        .index(this.currentIndex)
        .vertical(true)
        .loop(false)
        .indicator(false)
        .cachedCount(1)
        .duration(260)
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
          Text(`${this.currentIndex + 1}/${this.totalRecordCount}`)
            .fontSize(12)
            .fontColor('#D9FFFFFF')
        }
        Button(this.muted ? '有声' : '静音')
          .height(34)
          .fontSize(12)
          .fontColor(Color.White)
          .backgroundColor('#66000000')
          .borderRadius(17)
          .padding({ left: 12, right: 12 })
          .onClick(() => {
            this.muted = !this.muted;
          })
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
          Stack({ alignContent: Alignment.Center }) {
            Stack({ alignContent: Alignment.Center }) {
              Column()
                .width(30)
                .height(21)
                .borderRadius(15)
                .backgroundColor(Color.White)
              Column()
                .width(23)
                .height(14)
                .borderRadius(11)
                .backgroundColor('#12141A')
            }
            .width(30)
            .height(21)

            Column()
              .width(11)
              .height(11)
              .borderRadius(6)
              .backgroundColor(Color.White)
          }
          .width(48)
          .height(48)
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

  build() {
    if (this.session === null) {
      this.loginPage()
    } else {
      this.feedPage()
    }
  }
}
