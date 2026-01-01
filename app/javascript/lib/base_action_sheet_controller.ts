import { Controller } from "@hotwired/stimulus"

/**
 * BaseActionSheetController
 *
 * ボトムシート型モーダル（ActionSheet）の抽象基底クラス。
 * HTMLDialogElement を使用したモーダルの共通機能を提供します。
 *
 * 使用方法:
 * 1. このクラスを継承する
 * 2. eventPrefix ゲッターをオーバーライドしてイベント名のプレフィックスを返す
 * 3. onOpen() で初期化処理を実装
 * 4. onConfirm() で確定時のデータを返す
 *
 * イベント:
 * - `{eventPrefix}:open` を受信してモーダルを開く
 * - `{eventPrefix}:confirmed` を発火して確定を通知
 */
export abstract class BaseActionSheetController extends Controller {
	static targets = ["modal"]

	declare readonly modalTarget: HTMLDialogElement
	declare readonly hasModalTarget: boolean

	protected currentTrigger: any = null
	private boundOpen!: (event: Event) => void
	private boundHandleBackdropClick!: (event: MouseEvent) => void

	/**
	 * イベント名のプレフィックスを返す
	 * 例: "datepicker" → "datepicker:open", "datepicker:confirmed"
	 */
	abstract get eventPrefix(): string

	/**
	 * モーダルが開かれた時の初期化処理
	 * @param detail - CustomEvent の detail オブジェクト
	 */
	abstract onOpen(detail: any): void

	/**
	 * 確定時に呼ばれる。confirmed イベントの detail として返す値を返す
	 * @returns confirmed イベントの detail オブジェクト（null の場合はイベントを発火しない）
	 */
	abstract onConfirm(): any | null

	connect() {
		this.boundOpen = this.open.bind(this) as (event: Event) => void
		this.boundHandleBackdropClick = this.handleBackdropClick.bind(this)

		window.addEventListener(`${this.eventPrefix}:open`, this.boundOpen)
		if (this.hasModalTarget) {
			this.modalTarget.addEventListener('click', this.boundHandleBackdropClick)
		}
	}

	disconnect() {
		window.removeEventListener(`${this.eventPrefix}:open`, this.boundOpen)
		if (this.hasModalTarget) {
			this.modalTarget.removeEventListener('click', this.boundHandleBackdropClick)
		}
	}

	/**
	 * backdrop（モーダル外）クリック時の処理
	 * デフォルトでは confirm() を呼び出す
	 */
	protected handleBackdropClick(event: MouseEvent) {
		if (event.target === this.modalTarget) {
			this.confirm()
		}
	}

	/**
	 * モーダルを開く
	 */
	open(event: CustomEvent) {
		const { trigger, ...rest } = event.detail || {}
		this.currentTrigger = trigger

		this.onOpen(rest)

		if (this.hasModalTarget) {
			this.modalTarget.showModal()
		}
	}

	/**
	 * モーダルを閉じる
	 */
	close() {
		if (this.hasModalTarget) {
			this.modalTarget.close()
		}
	}

	/**
	 * 確定してモーダルを閉じる
	 */
	confirm() {
		const detail = this.onConfirm()

		if (detail !== null && this.currentTrigger) {
			window.dispatchEvent(new CustomEvent(`${this.eventPrefix}:confirmed`, {
				detail: {
					...detail,
					trigger: this.currentTrigger
				}
			}))
		}

		this.close()
	}
}
