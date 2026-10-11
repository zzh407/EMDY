import { common } from '@kit.AbilityKit';
import { display, window } from '@kit.ArkUI';
import { AppSettings } from '../service/AppSettings';
import { FavoriteStore } from '../service/FavoriteStore';
import { EmbyClient, EmbyVideoQuery } from '../service/EmbyClient';
import { SessionStore } from '../service/SessionStore';
import { EmbyLibrary, EmbyPlaybackMode, EmbySession, EmbyVideo, EmbyVideoPage, EmbyViewsSummary } from '../model/EmbyModels';

@Component
struct ShortVideoCard {
  @Prop item: EmbyVideo = new EmbyVideo();
  @Prop @Watch('onActiveChanged') active: boolean = false;
  @Prop @Watch('onMutedChanged') muted: boolean = false;
  @Prop bottomSafePadding: number = 0;
  @Prop @Watch('onPlayModeChanged') playMode: string = 'off';
  @Prop @Watch('onImmersiveChanged') immersive: boolean = true;
  @Prop controlsHidden: boolean = false;
  @Prop fastSpeed: number = 2.0;
  onTogglePlayMode: (hint: string) => void = () => {};
  onToggleImmersive: (hint: string) => void = () => {};
  onToggleMute: (hint: string) => void = () => {};
  onHideControls: () => void = () => {};
  onPlaybackEnd: () => void = () => {};
  onToggleFavorite: (item: EmbyVideo) => void = () => {};
  @Prop @Watch('onFavoriteChanged') isFavorite: boolean = false;
  @State isPlaying: boolean = false;
  @State hasStarted: boolean = false;
  @State hasError: boolean = false;
  @State modeIndex: number = 0;
  @State currentSrc: string = '';
  @State currentSpeed: number = 1.0;
  @State isBoosting: boolean = false;
  @State showProgress: boolean = false;
  @State progressValue: number = 0;
  @State progressMax: number = 0;
  @State isSeeking: boolean = false;
  private controller: VideoController = new VideoController();
  private lastItemId: string = '';
  private progressHideTimer: number = 0;
  private lastSeekTime: number = 0;
  @State isScrubbing: boolean = false;
  @State scrubValue: number = 0;
  @State showScrubFeedback: boolean = false;
  private scrubStartProgress: number = 0;
  private screenW: number = 0;
  private favoriteHeartCanvas: CanvasRenderingContext2D = new CanvasRenderingContext2D();
  private playModeCanvas: CanvasRenderingContext2D = new CanvasRenderingContext2D();
  private fullscreenCanvas: CanvasRenderingContext2D = new CanvasRenderingContext2D();
  private hideEyeCanvas: CanvasRenderingContext2D = new CanvasRenderingContext2D();
  private muteCanvas: CanvasRenderingContext2D = new CanvasRenderingContext2D();


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
      this.progressValue = 0;
      this.progressMax = 0;
      this.showProgress = false;
      this.isSeeking = false;
      this.currentSpeed = 1.0;
      this.isBoosting = false;
      this.lastSeekTime = 0;
      this.isScrubbing = false;
      this.showScrubFeedback = false;
      this.clearProgressHide();
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
    return this.playMode === 'shuffle' ? '播放模式：顺序播放' : '播放模式：随机播放';
  }

  @Builder
  private playModeButtonIcon() {
    Canvas(this.playModeCanvas)
      .width(28)
      .height(28)
      .onReady(() => {
        this.paintPlayModeIcon();
      })
  }

  @Builder
  private fullscreenButtonIcon() {
    Canvas(this.fullscreenCanvas)
      .width(28)
      .height(28)
      .onReady(() => {
        this.paintFullscreenIcon();
      })
  }

  @Builder
  private hideButtonIcon() {
    Canvas(this.hideEyeCanvas)
      .width(28)
      .height(28)
      .onReady(() => {
        this.paintHideEye();
      })
  }

  @Builder
  private muteButtonIcon() {
    Canvas(this.muteCanvas)
      .width(28)
      .height(28)
      .onReady(() => {
        this.paintMuteIcon();
      })
  }

  private onPlayModeChanged(): void {
    this.paintPlayModeIcon();
  }

  private onImmersiveChanged(): void {
    this.paintFullscreenIcon();
  }

  private onMutedChanged(): void {
    this.paintMuteIcon();
  }

  private onFavoriteChanged(): void {
    this.paintFavoriteHeart();
  }

  private beginIcon(ctx: CanvasRenderingContext2D, color: string): void {
    ctx.clearRect(0, 0, ctx.width, ctx.height);
    const s = ctx.width / 28;
    ctx.save();
    ctx.scale(s, s);
    ctx.strokeStyle = color;
    ctx.fillStyle = color;
    ctx.lineWidth = 2.2;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
  }

  private endIcon(ctx: CanvasRenderingContext2D): void {
    ctx.restore();
  }

  private paintPlayModeIcon(): void {
    const ctx = this.playModeCanvas;
    if (ctx.width <= 0) {
      return;
    }
    const color = this.playModeActive() ? '#FFFFFF' : '#A9B0C0';
    this.beginIcon(ctx, color);
    if (this.playMode === 'shuffle') {
      ctx.beginPath();
      ctx.moveTo(6, 20);
      ctx.lineTo(20, 6);
      ctx.moveTo(20, 6);
      ctx.lineTo(14, 6);
      ctx.moveTo(20, 6);
      ctx.lineTo(20, 12);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(6, 6);
      ctx.lineTo(20, 20);
      ctx.moveTo(20, 20);
      ctx.lineTo(14, 20);
      ctx.moveTo(20, 20);
      ctx.lineTo(20, 14);
      ctx.stroke();
    } else {
      ctx.beginPath();
      ctx.moveTo(4, 14);
      ctx.lineTo(20, 14);
      ctx.moveTo(20, 14);
      ctx.lineTo(15, 9);
      ctx.moveTo(20, 14);
      ctx.lineTo(15, 19);
      ctx.stroke();
    }
    this.endIcon(ctx);
  }

  private paintFullscreenIcon(): void {
    const ctx = this.fullscreenCanvas;
    if (ctx.width <= 0) {
      return;
    }
    const color = this.immersive ? '#FFFFFF' : '#A9B0C0';
    this.beginIcon(ctx, color);
    const m = 5;
    const len = 6;
    const w = 28;
    const h = 28;
    ctx.beginPath();
    if (this.immersive) {
      ctx.moveTo(m + len, m);
      ctx.lineTo(m + len, m + len);
      ctx.lineTo(m, m + len);
      ctx.moveTo(w - m - len, m);
      ctx.lineTo(w - m - len, m + len);
      ctx.lineTo(w - m, m + len);
      ctx.moveTo(m, h - m - len);
      ctx.lineTo(m + len, h - m - len);
      ctx.lineTo(m + len, h - m);
      ctx.moveTo(w - m - len, h - m);
      ctx.lineTo(w - m - len, h - m - len);
      ctx.lineTo(w - m, h - m - len);
    } else {
      ctx.moveTo(m, m + len);
      ctx.lineTo(m, m);
      ctx.lineTo(m + len, m);
      ctx.moveTo(w - m - len, m);
      ctx.lineTo(w - m, m);
      ctx.lineTo(w - m, m + len);
      ctx.moveTo(m, h - m - len);
      ctx.lineTo(m, h - m);
      ctx.lineTo(m + len, h - m);
      ctx.moveTo(w - m, h - m - len);
      ctx.lineTo(w - m, h - m);
      ctx.lineTo(w - m - len, h - m);
    }
    ctx.stroke();
    this.endIcon(ctx);
  }

  private paintHideEye(): void {
    const ctx = this.hideEyeCanvas;
    if (ctx.width <= 0) {
      return;
    }
    this.beginIcon(ctx, '#FFFFFF');
    const cx = 14;
    const cy = 14;
    const rx = 11;
    const ry = 7;
    ctx.beginPath();
    ctx.ellipse(cx, cy, rx, ry, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(cx - rx, cy + ry * 0.85);
    ctx.lineTo(cx + rx, cy - ry * 0.85);
    ctx.stroke();
    this.endIcon(ctx);
  }

  private paintMuteIcon(): void {
    const ctx = this.muteCanvas;
    if (ctx.width <= 0) {
      return;
    }
    const color = this.muted ? '#FFFFFF' : '#A9B0C0';
    this.beginIcon(ctx, color);
    ctx.beginPath();
    ctx.moveTo(4, 11);
    ctx.lineTo(10, 11);
    ctx.lineTo(16, 6);
    ctx.lineTo(16, 22);
    ctx.lineTo(10, 17);
    ctx.lineTo(4, 17);
    ctx.closePath();
    ctx.stroke();
    if (this.muted) {
      ctx.beginPath();
      ctx.moveTo(19, 9);
      ctx.lineTo(25, 19);
      ctx.moveTo(25, 9);
      ctx.lineTo(19, 19);
      ctx.stroke();
    } else {
      ctx.beginPath();
      ctx.arc(18, 14, 4.5, -Math.PI / 3, Math.PI / 3);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(18, 14, 7.5, -Math.PI / 3, Math.PI / 3);
      ctx.stroke();
    }
    this.endIcon(ctx);
  }

  private nextModeLabel(): string {
    const modes: Array<EmbyPlaybackMode> = this.item.playbackModes.length > 0 ?
      this.item.playbackModes : ['direct'];
    const nextIndex = (this.modeIndex + 1) % modes.length;
    return `兼容模式：${this.item.labelOf(modes[nextIndex])}`;
  }

  private formatTime(seconds: number): string {
    if (seconds <= 0) {
      return '00:00';
    }
    const total: number = Math.floor(seconds);
    const h: number = Math.floor(total / 3600);
    const remainingSeconds: number = total % 3600;
    const m: number = Math.floor(remainingSeconds / 60);
    const s: number = total % 60;
    const mm: string = m < 10 ? `0${m}` : `${m}`;
    const ss: string = s < 10 ? `0${s}` : `${s}`;
    if (h > 0) {
      const hh: string = h < 10 ? `0${h}` : `${h}`;
      return `${hh}:${mm}:${ss}`;
    }
    return `${mm}:${ss}`;
  }

  private clearProgressHide(): void {
    if (this.progressHideTimer !== 0) {
      clearTimeout(this.progressHideTimer);
      this.progressHideTimer = 0;
    }
  }

  private scheduleHideProgress(): void {
    this.clearProgressHide();
    this.progressHideTimer = setTimeout(() => {
      this.showProgress = false;
      this.progressHideTimer = 0;
    }, 1200);
  }

  private seekTo(value: number): void {
    if (this.progressMax <= 0) {
      return;
    }
    this.progressValue = value;
    this.lastSeekTime = Date.now();
    this.controller.setCurrentTime(value);
  }

  private endBoost(): void {
    this.isBoosting = false;
    this.currentSpeed = 1.0;
  }

  private beginScrub(): void {
    if (this.progressMax <= 0) {
      return;
    }
    try {
      const displayClass = display.getDefaultDisplaySync();
      const density = displayClass.densityPixels > 0 ? displayClass.densityPixels : 1;
      this.screenW = displayClass.width / density;
    } catch (error) {
      this.screenW = 360;
    }
    this.isSeeking = true;
    this.isScrubbing = true;
    this.scrubStartProgress = this.progressValue;
    this.scrubValue = this.progressValue;
    this.showProgress = true;
    this.showScrubFeedback = true;
    this.clearProgressHide();
  }

  private updateScrub(deltaVp: number): void {
    if (!this.isScrubbing || this.progressMax <= 0) {
      return;
    }
    if (this.screenW <= 0) {
      return;
    }
    const deltaSeconds = deltaVp / this.screenW * this.progressMax;
    const next = this.scrubStartProgress + deltaSeconds;
    this.scrubValue = next < 0 ? 0 : (next > this.progressMax ? this.progressMax : next);
  }

  private endScrub(): void {
    if (!this.isScrubbing) {
      return;
    }
    this.isScrubbing = false;
    this.showScrubFeedback = false;
    this.seekTo(this.scrubValue);
    this.isSeeking = false;
    this.scheduleHideProgress();
  }

  private favoriteActive(): boolean {
    return this.isFavorite;
  }

  private paintFavoriteHeart(): void {
    const ctx = this.favoriteHeartCanvas;
    if (ctx.width <= 0) {
      return;
    }
    const active = this.favoriteActive();
    ctx.clearRect(0, 0, ctx.width, ctx.height);
    const s = ctx.width / 28;
    ctx.save();
    ctx.scale(s, s);
    ctx.strokeStyle = active ? '#FF5E7A' : '#FFFFFF';
    ctx.fillStyle = active ? '#FF5E7A' : 'rgba(0,0,0,0)';
    ctx.lineWidth = 2.2;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.beginPath();
    ctx.moveTo(14, 23);
    ctx.bezierCurveTo(6, 17, 4, 12, 4, 9);
    ctx.bezierCurveTo(4, 5.7, 6.6, 4, 9, 4);
    ctx.bezierCurveTo(11, 4, 13, 5.2, 14, 7.5);
    ctx.bezierCurveTo(15, 5.2, 17, 4, 19, 4);
    ctx.bezierCurveTo(21.4, 4, 24, 5.7, 24, 9);
    ctx.bezierCurveTo(24, 12, 22, 17, 14, 23);
    ctx.closePath();
    if (active) {
      ctx.fill();
    }
    ctx.stroke();
    ctx.restore();
  }

  @Builder
  private progressBar() {
    Row({ space: 8 }) {
      Text(this.formatTime(this.isScrubbing ? this.scrubValue : this.progressValue))
        .fontSize(11)
        .fontColor(Color.White)
      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(4)
          .borderRadius(2)
          .backgroundColor('#33FFFFFF')
        Row()
          .width(this.progressMax > 0
            ? `${((this.isScrubbing ? this.scrubValue : this.progressValue) / this.progressMax) * 100}%`
            : '0%')
          .height(4)
          .borderRadius(2)
          .backgroundColor('#5B74F6')
      }
      .layoutWeight(1)
      .hitTestBehavior(HitTestMode.None)
      Text(this.formatTime(this.progressMax))
        .fontSize(11)
        .fontColor(Color.White)
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 6 })
    .visibility(this.showProgress ? Visibility.Visible : Visibility.None)
    .hitTestBehavior(HitTestMode.Transparent)
  }

  aboutToDisappear(): void {
    this.clearProgressHide();
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
        currentProgressRate: this.currentSpeed,
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
        .onPrepared((event: PreparedInfo) => {
          if (event.duration > 0) {
            this.progressMax = event.duration;
          }
        })
        .onUpdate((event: PlaybackInfo) => {
          if (this.isSeeking) {
            return;
          }
          if (this.lastSeekTime > 0 && Date.now() - this.lastSeekTime < 300) {
            return;
          }
          this.lastSeekTime = 0;
          this.progressValue = event.time;
        })
        .onClick(() => this.togglePlayback())
        .gesture(
          LongPressGesture({ repeat: false, duration: 400 })
            .onAction(() => {
              if (!this.isPlaying || this.fastSpeed <= 1.0) {
                return;
              }
              this.currentSpeed = this.fastSpeed;
              this.isBoosting = true;
            })
            .onActionEnd(() => this.endBoost())
            .onActionCancel(() => this.endBoost())
        )
        .gesture(
          PanGesture({ fingers: 1, direction: PanDirection.Horizontal, distance: 12 })
            .onActionStart(() => this.beginScrub())
            .onActionUpdate((event: GestureEvent) => this.updateScrub(event.offsetX))
            .onActionEnd(() => this.endScrub())
            .onActionCancel(() => this.endScrub())
        )

      if (this.isScrubbing) {
        Column({ space: 2 }) {
          Text(`${this.formatTime(this.scrubValue)} / ${this.formatTime(this.progressMax)}`)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
          Text('松手跳转到此时间')
            .fontSize(10)
        }
        .alignItems(HorizontalAlign.Center)
        .padding({ left: 18, right: 18, top: 12, bottom: 12 })
        .borderRadius(16)
        .backgroundColor('#66000000')
        .hitTestBehavior(HitTestMode.None)
      }

      if (this.isBoosting && this.currentSpeed > 1.0) {
        Column({ space: 2 }) {
          Text(`${this.currentSpeed.toFixed(1)}x`)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Text('倍速播放中')
            .fontSize(11)
            .fontColor('#B8FFFFFF')
        }
        .alignItems(HorizontalAlign.Center)
        .padding({ left: 22, right: 22, top: 14, bottom: 14 })
        .borderRadius(18)
        .backgroundColor('#66000000')
        .hitTestBehavior(HitTestMode.None)
      }

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
        this.progressBar()
        this.itemCaption(this.bottomSafePadding)
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.Transparent)

      if (!this.controlsHidden) {
        Column() {
          Column({ space: 14 }) {
            Column() {
              Canvas(this.favoriteHeartCanvas)
                .width(28)
                .height(28)
                .onReady(() => {
                  this.paintFavoriteHeart();
                })
            }
            .width(48)
            .height(48)
            .justifyContent(FlexAlign.Center)
            .borderRadius(24)
            .backgroundColor(this.favoriteActive() ? '#59FF5E7A' : '#66000000')
            .onClick(() => {
              this.onToggleFavorite(this.item);
            })

            Column() {
              this.playModeButtonIcon()
            }
            .width(48)
            .height(48)
            .justifyContent(FlexAlign.Center)
            .borderRadius(24)
            .backgroundColor(this.playModeActive() ? '#5B74F6' : '#66000000')
            .onClick(() => this.onTogglePlayMode(this.playModeHint()))

            Column() {
              this.fullscreenButtonIcon()
            }
            .width(48)
            .height(48)
            .justifyContent(FlexAlign.Center)
            .borderRadius(24)
            .backgroundColor(this.immersive ? '#5B74F6' : '#66000000')
            .onClick(() => this.onToggleImmersive(this.immersive ? '已退出全屏' : '已切换为全屏'))

            Column() {
              this.muteButtonIcon()
            }
            .width(48)
            .height(48)
            .justifyContent(FlexAlign.Center)
            .borderRadius(24)
            .backgroundColor(this.muted ? '#5B74F6' : '#66000000')
            .onClick(() => this.onToggleMute(this.muted ? '已开启声音' : '已静音'))

            Column() {
              this.hideButtonIcon()
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
  private deviceId: string = '';
  private client: EmbyClient | null = null;
  private hintTimer: number = 0;
  @State private favorites: Array<EmbyVideo> = [];
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

  private isFavoriteVideo(video: EmbyVideo): boolean {
    return this.favorites.some((item: EmbyVideo) => item.id === video.id);
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
      if (this.shufflePlayback && reset) {
        const all: Array<EmbyVideo> = await this.loadAllVideos();
        this.videos = this.shuffleList(all);
        this.totalRecordCount = all.length;
        this.hasMore = false;
        this.feedSourceCount = all.length;
      } else {
        const query = new EmbyVideoQuery();
        query.libraryId = this.selectedLibraryId;
        query.hideCollections = this.hideCollections;
        const startIndex = reset ? 0 : this.feedSourceCount;
        const page: EmbyVideoPage = await client.getVideos(startIndex, this.pageSize, query);
        if (reset) {
          this.videos = page.items;
        } else {
          this.videos = this.videos.concat(page.items);
        }
        this.feedSourceCount = this.feedSourceCount + page.items.length;
        this.totalRecordCount = page.totalRecordCount;
        this.hasMore = this.videos.length < page.totalRecordCount && page.items.length > 0;
      }
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
      this.mediaListItems = this.mediaListItems.concat(page.items);
      this.mediaListTotal = page.totalRecordCount;
      this.mediaListHasMore = this.mediaListItems.length < page.totalRecordCount && page.items.length > 0;
    } catch (error) {
      this.errorMessage = this.describeError(error as Error);
    } finally {
      this.mediaListLoading = false;
    }
  }

  private playFromList(item: EmbyVideo): void {
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
        Button('全部媒体')
          .height(34)
          .fontSize(12)
          .fontColor(Color.White)
          .backgroundColor('#66000000')
          .borderRadius(17)
          .padding({ left: 12, right: 12 })
          .onClick(() => this.openMediaList())
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
          .aspectRatio(16 / 9)
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
      }
      .width('100%')
      .aspectRatio(16 / 9)
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
    .onClick(() => this.playFromList(item))
  }

  @Builder
  private mediaListPage() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#090A0F')

      Column() {
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
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })

        Grid(this.gridScroller) {
          ForEach(this.mediaListItems, (item: EmbyVideo) => {
            GridItem() {
              this.mediaGridItem(item)
            }
          }, (item: EmbyVideo) => item.id)
        }
        .columnsTemplate('1fr 1fr 1fr')
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
    if (this.mediaListVisible) {
      this.mediaListVisible = false;
      return true;
    }
    return false;
  }

  build() {
    if (this.session === null) {
      this.loginPage()
    } else if (this.mediaListVisible) {
      this.mediaListPage()
    } else {
      this.feedPage()
    }
  }
}
