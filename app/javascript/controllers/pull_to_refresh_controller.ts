import { Controller } from "@hotwired/stimulus";

/**
 * Pull to Refresh Controller
 * モバイルデバイスでプルダウン時にページをリフレッシュする
 */
export default class extends Controller {
	static targets = ["indicator"];

	declare indicatorTarget: HTMLElement;
	declare hasIndicatorTarget: boolean;

	private startY: number = 0;
	private currentY: number = 0;
	private pulling: boolean = false;
	private refreshing: boolean = false;
	private threshold: number = 80; // リフレッシュを発動する閾値（px）

	private boundHandleTouchStart: EventListener = () => { };
	private boundHandleTouchMove: EventListener = () => { };
	private boundHandleTouchEnd: EventListener = () => { };

	connect() {
		this.boundHandleTouchStart = this.handleTouchStart.bind(this) as EventListener;
		this.boundHandleTouchMove = this.handleTouchMove.bind(this) as EventListener;
		this.boundHandleTouchEnd = this.handleTouchEnd.bind(this) as EventListener;
		this.bindTouchEvents();
	}

	disconnect() {
		this.unbindTouchEvents();
	}

	private bindTouchEvents() {
		this.element.addEventListener("touchstart", this.boundHandleTouchStart, {
			passive: true,
		});
		this.element.addEventListener("touchmove", this.boundHandleTouchMove, {
			passive: false,
		});
		this.element.addEventListener("touchend", this.boundHandleTouchEnd, {
			passive: true,
		});
	}

	private unbindTouchEvents() {
		this.element.removeEventListener("touchstart", this.boundHandleTouchStart);
		this.element.removeEventListener("touchmove", this.boundHandleTouchMove);
		this.element.removeEventListener("touchend", this.boundHandleTouchEnd);
	}

	private handleTouchStart(event: TouchEvent) {
		// ページが一番上にスクロールされている場合のみ有効
		if (window.scrollY === 0 && !this.refreshing) {
			this.startY = event.touches[0].clientY;
			this.pulling = true;
		}
	}

	private handleTouchMove(event: TouchEvent) {
		if (!this.pulling || this.refreshing) return;

		this.currentY = event.touches[0].clientY;
		const pullDistance = this.currentY - this.startY;

		// 下方向へのプルのみ処理
		if (pullDistance > 0 && window.scrollY === 0) {
			// ブラウザのデフォルトスクロールを防止
			event.preventDefault();

			// 引っ張り距離に応じてインジケータを表示
			const progress = Math.min(pullDistance / this.threshold, 1);
			this.updateIndicator(pullDistance, progress);
		}
	}

	private handleTouchEnd() {
		if (!this.pulling || this.refreshing) return;

		const pullDistance = this.currentY - this.startY;

		if (pullDistance >= this.threshold) {
			this.triggerRefresh();
		} else {
			this.resetIndicator();
		}

		this.pulling = false;
		this.startY = 0;
		this.currentY = 0;
	}

	private updateIndicator(pullDistance: number, progress: number) {
		if (!this.hasIndicatorTarget) return;

		const indicator = this.indicatorTarget;
		const displayDistance = Math.min(pullDistance * 0.5, 60);

		indicator.style.transform = `translateY(${displayDistance}px)`;
		indicator.style.opacity = String(progress);

		// 回転アニメーション
		const rotation = progress * 180;
		const spinner = indicator.querySelector(".pull-refresh-spinner");
		if (spinner) {
			(spinner as HTMLElement).style.transform = `rotate(${rotation}deg)`;
		}

		// 閾値を超えたらアクティブ状態に
		if (progress >= 1) {
			indicator.classList.add("pull-refresh-ready");
		} else {
			indicator.classList.remove("pull-refresh-ready");
		}
	}

	private resetIndicator() {
		if (!this.hasIndicatorTarget) return;

		const indicator = this.indicatorTarget;
		indicator.style.transform = "translateY(0)";
		indicator.style.opacity = "0";
		indicator.classList.remove("pull-refresh-ready", "pull-refresh-loading");
	}

	private triggerRefresh() {
		this.refreshing = true;

		if (this.hasIndicatorTarget) {
			const indicator = this.indicatorTarget;
			indicator.classList.add("pull-refresh-loading");
			indicator.classList.remove("pull-refresh-ready");
			indicator.style.transform = "translateY(50px)";
			indicator.style.opacity = "1";
		}

		// 少し遅延させてからリロード（アニメーションを見せるため）
		setTimeout(() => {
			window.location.reload();
		}, 500);
	}
}
