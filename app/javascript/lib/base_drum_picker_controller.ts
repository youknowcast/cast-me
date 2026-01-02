import { BaseActionSheetController } from "./base_action_sheet_controller"

/**
 * BaseDrumPickerController
 *
 * ドラムホイール型ピッカーの抽象基底クラス。
 * BaseActionSheetController を継承し、スクロールスナップによる
 * ドラム式選択UIの共通機能を提供します。
 *
 * 使用方法:
 * 1. このクラスを継承する
 * 2. wheelTargets を定義して各ホイールの要素を指定
 * 3. renderWheels() でホイールの内容を描画
 * 4. scrollToSelected() で選択位置にスクロール
 */
export abstract class BaseDrumPickerController extends BaseActionSheetController {
	protected itemHeight = 44 // Height of each wheel item in pixels

	/**
	 * ホイールアイテムを作成する
	 * @param value - アイテムの値
	 * @param displayText - 表示テキスト
	 * @param onClick - クリック時のコールバック
	 */
	protected createWheelItem(
		value: number,
		displayText: string,
		onClick: (value: number) => void
	): HTMLElement {
		const item = document.createElement('button')
		item.type = 'button'
		item.className = 'w-full h-11 flex items-center justify-center text-xl font-medium text-gray-400 transition-all duration-150 touch-manipulation'
		item.textContent = displayText
		item.dataset.value = String(value)

		item.addEventListener('click', () => onClick(value))

		return item
	}

	/**
	 * ホイールを指定位置にスクロール
	 * @param wheelContainer - スクロールコンテナ（.parentElement）
	 * @param index - スクロール先のインデックス
	 * @param smooth - スムーズスクロールするか
	 */
	protected scrollWheelTo(wheelContainer: HTMLElement | null, index: number, smooth = true) {
		if (!wheelContainer) return

		const scrollTop = index * this.itemHeight
		wheelContainer.scrollTo({
			top: scrollTop,
			behavior: smooth ? 'smooth' : 'instant' as any
		})
	}

	/**
	 * スクロール位置からインデックスを計算
	 * @param container - スクロールコンテナ
	 * @returns インデックス
	 */
	protected getIndexFromScroll(container: HTMLElement): number {
		return Math.round(container.scrollTop / this.itemHeight)
	}

	/**
	 * ホイールアイテムの選択状態を更新
	 * @param wheelTarget - ホイール要素
	 * @param selectedValue - 選択された値
	 */
	protected updateWheelHighlight(wheelTarget: HTMLElement, selectedValue: number) {
		wheelTarget.querySelectorAll('button').forEach((btn) => {
			const btnValue = parseInt(btn.dataset.value || '0')
			if (btnValue === selectedValue) {
				btn.classList.remove('text-gray-400')
				btn.classList.add('text-gray-900', 'font-bold', 'text-2xl')
			} else {
				btn.classList.remove('text-gray-900', 'font-bold', 'text-2xl')
				btn.classList.add('text-gray-400')
			}
		})
	}

	/**
	 * ホイールの内容を描画（サブクラスで実装）
	 */
	abstract renderWheels(): void

	/**
	 * 選択位置にスクロールする（サブクラスで実装）
	 */
	abstract scrollToSelected(): void
}
