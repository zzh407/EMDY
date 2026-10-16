import { display } from '@kit.ArkUI';
import { EmbyPlaybackMode, EmbyVideo } from '../model/EmbyModels';

interface TagLabel {
  name: string;
  kind: string;
}

@Component
export struct ShortVideoCard {
  @Prop @Watch('onItemChanged') item: EmbyVideo = new EmbyVideo();
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
  onOpenAuthor: (item: EmbyVideo) => void = () => {};
  onFilterTag: (tag: string, kind: string) => void = () => {};
  onDeleteVideo: (item: EmbyVideo) => void = () => {};
  @Prop @Watch('onFavoriteChanged') isFavorite: boolean = false;
  @Prop @Watch('onDeletePendingChanged') deletePending: boolean = false;
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
  private lastLiveSeekTime: number = 0;
  private lastLiveSeekTarget: number = -1;
  private scrubWasPlaying: boolean = false;
  @State isScrubbing: boolean = false;
  @State scrubValue: number = 0;
  @State showScrubFeedback: boolean = false;
  private scrubStartProgress: number = 0;
  private screenW: number = 0;
  private favoriteHeartCanvas: CanvasRenderingContext2D = new CanvasRenderingContext2D();
  private trashCanvas: CanvasRenderingContext2D = new CanvasRenderingContext2D();
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
    this.paintTrashIcon();
  }

  private onItemChanged(): void {
    // Swiper 复用卡片时 item 会变化，需无条件重置播放器状态
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
    this.lastLiveSeekTime = 0;
    this.lastLiveSeekTarget = -1;
    this.isScrubbing = false;
    this.showScrubFeedback = false;
    this.clearProgressHide();
    this.hasStarted = false;
    this.hasError = false;
    this.isPlaying = false;
    this.controller.stop();
    if (this.active) {
      this.controller.start();
    }
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
      this.lastLiveSeekTime = 0;
      this.lastLiveSeekTarget = -1;
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
      this.item.overview.length > 0 || this.tagLabels().length > 0)) {
      Row({ space: 12 }) {
        if (this.item.authorAvatar.length > 0) {
          Image(this.item.authorAvatar)
            .width(46)
            .height(46)
            .borderRadius(23)
            .objectFit(ImageFit.Cover)
            .alt($r('app.media.startIcon'))
            .onClick(() => this.onOpenAuthor(this.item))
        } else {
          Stack({ alignContent: Alignment.Center }) {
            Text(this.item.authorInitial())
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
          .width(46)
          .onClick(() => this.onOpenAuthor(this.item))
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
            .onClick(() => this.onOpenAuthor(this.item))
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
          if (this.tagLabels().length > 0) {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.tagLabels(), (label: TagLabel) => {
                Text(`# ${label.name}`)
                  .fontSize(12)
                  .fontColor('#9EC1FF')
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                  .backgroundColor('#1E2A4A')
                  .borderRadius(12)
                  .margin({ right: 6, bottom: 6 })
                  .onClick(() => this.onFilterTag(label.name, label.kind))
              }, (label: TagLabel) => label.name)
            }
            .width('100%')
            .margin({ top: 2 })
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

  private maxSeekTarget(): number {
    return this.progressMax > 1 ? this.progressMax - 1 : this.progressMax;
  }

  private seekTo(value: number): void {
    if (this.progressMax <= 0) {
      return;
    }
    const target = value > this.maxSeekTarget() ? this.maxSeekTarget() : value;
    this.progressValue = target;
    this.lastSeekTime = Date.now();
    this.controller.setCurrentTime(target);
  }

  private endBoost(): void {
    this.isBoosting = false;
    this.currentSpeed = 1.0;
  }

  private beginScrub(): void {
    if (this.deletePending || this.progressMax <= 0) {
      return;
    }
    try {
      const displayClass = display.getDefaultDisplaySync();
      const density = displayClass.densityPixels > 0 ? displayClass.densityPixels : 1;
      this.screenW = displayClass.width / density;
    } catch (error) {
      this.screenW = 360;
    }
    this.scrubWasPlaying = this.isPlaying;
    if (this.scrubWasPlaying) {
      this.controller.pause();
    }
    this.isSeeking = true;
    this.isScrubbing = true;
    this.scrubStartProgress = this.progressValue;
    this.scrubValue = this.progressValue;
    this.lastLiveSeekTime = 0;
    this.lastLiveSeekTarget = -1;
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
    const clamped = next < 0 ? 0 : (next > this.progressMax ? this.progressMax : next);
    if (clamped !== this.scrubValue) {
      this.scrubValue = clamped;
      this.requestLiveSeek(clamped);
    }
  }

  private requestLiveSeek(target: number): void {
    const now = Date.now();
    const limit = this.maxSeekTarget();
    const finalTarget = target > limit ? limit : target;
    if (this.lastLiveSeekTarget >= 0 && Math.abs(finalTarget - this.lastLiveSeekTarget) < 0.2) {
      return;
    }
    if (now - this.lastLiveSeekTime < 250) {
      return;
    }
    this.lastLiveSeekTime = now;
    this.lastLiveSeekTarget = finalTarget;
    this.lastSeekTime = now;
    this.controller.setCurrentTime(finalTarget, SeekMode.PreviousKeyframe);
    this.progressValue = finalTarget;
  }

  private endScrub(): void {
    if (!this.isScrubbing) {
      return;
    }
    this.isScrubbing = false;
    this.showScrubFeedback = false;
    this.lastLiveSeekTime = 0;
    this.lastLiveSeekTarget = -1;
    this.seekTo(this.scrubValue);
    this.isSeeking = false;
    if (this.scrubWasPlaying) {
      this.controller.start();
    }
    this.scheduleHideProgress();
  }

  private favoriteActive(): boolean {
    return this.isFavorite;
  }

  private onDeletePendingChanged(): void {
    this.paintTrashIcon();
  }

  private tagLabels(): Array<TagLabel> {
    // 合并 Genres（nfo genre）与 Tags，去重并保持 genres 在前的稳定顺序
    const labels: Array<TagLabel> = [];
    this.item.genres.forEach((name: string) => {
      if (!labels.some((label: TagLabel) => label.name === name)) {
        labels.push({ name: name, kind: 'genres' });
      }
    });
    this.item.tags.forEach((name: string) => {
      if (!labels.some((label: TagLabel) => label.name === name)) {
        labels.push({ name: name, kind: 'tags' });
      }
    });
    return labels;
  }

  private paintTrashIcon(): void {
    const ctx = this.trashCanvas;
    if (ctx.width <= 0) {
      return;
    }
    const color = this.deletePending ? 'rgba(255,59,48,0.45)' : '#FF3B30';
    this.beginIcon(ctx, color);
    // 桶盖横线
    ctx.beginPath();
    ctx.moveTo(4.5, 7.5);
    ctx.lineTo(19.5, 7.5);
    ctx.stroke();
    // 盖子提手
    ctx.beginPath();
    ctx.moveTo(9.8, 7.5);
    ctx.lineTo(9.8, 5.2);
    ctx.moveTo(14.2, 7.5);
    ctx.lineTo(14.2, 5.2);
    ctx.moveTo(9.8, 5.2);
    ctx.lineTo(14.2, 5.2);
    ctx.stroke();
    // 桶身
    ctx.beginPath();
    ctx.moveTo(6.6, 7.5);
    ctx.lineTo(7.8, 20.6);
    ctx.moveTo(17.4, 7.5);
    ctx.lineTo(16.2, 20.6);
    ctx.moveTo(8.6, 20.6);
    ctx.lineTo(15.4, 20.6);
    ctx.stroke();
    // 桶身竖纹
    ctx.beginPath();
    ctx.moveTo(10.6, 10.5);
    ctx.lineTo(11.2, 17.8);
    ctx.moveTo(13.4, 10.5);
    ctx.lineTo(12.8, 17.8);
    ctx.stroke();
    this.endIcon(ctx);
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

      if (this.active && !this.isPlaying && this.hasStarted && !this.hasError && !this.isScrubbing) {
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

            Column() {
              Canvas(this.trashCanvas)
                .width(28)
                .height(28)
                .onReady(() => {
                  this.paintTrashIcon();
                })
            }
            .width(48)
            .height(48)
            .justifyContent(FlexAlign.Center)
            .borderRadius(24)
            .backgroundColor(this.deletePending ? '#66FF3B30' : '#66000000')
            .opacity(this.deletePending ? 0.6 : 1)
            .onClick(() => {
              if (!this.deletePending) {
                this.onDeleteVideo(this.item);
              }
            })
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