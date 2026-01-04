import { Controller } from "@hotwired/stimulus"

/**
 * Task Completion Controller
 * タスク完了時の紙吹雪アニメーションを制御
 */
export default class extends Controller {
	static targets = ["checkbox"]

	declare checkboxTarget: HTMLInputElement

	// チェックボックスの変更時
	toggle(event: Event) {
		const checkbox = event.target as HTMLInputElement

		// 完了になったときのみアニメーションを発火
		if (checkbox.checked) {
			this.celebrate()
		}

		// フォームを送信
		const form = checkbox.closest("form") as HTMLFormElement
		if (form) {
			form.requestSubmit()
		}
	}

	// 紙吹雪アニメーション
	private celebrate() {
		const colors = ["#fbbf24", "#f59e0b", "#ef4444", "#10b981", "#3b82f6", "#8b5cf6"]

		// 固定オーバーレイコンテナを取得または作成
		let overlay = document.getElementById("confetti-overlay")
		if (!overlay) {
			overlay = document.createElement("div")
			overlay.id = "confetti-overlay"
			overlay.className = "confetti-overlay"
			document.body.appendChild(overlay)
		}

		// タスクコンテナの位置を取得
		const container = this.element as HTMLElement
		const rect = container.getBoundingClientRect()
		const containerWidth = rect.width
		const startY = rect.top

		// 紙吹雪を生成
		for (let i = 0; i < 25; i++) {
			const confetti = document.createElement("div")
			confetti.className = "confetti"
			confetti.style.setProperty("--confetti-color", colors[Math.floor(Math.random() * colors.length)])

			// タスクコンテナの幅全体にランダム配置
			const offsetX = Math.random() * containerWidth
			confetti.style.left = `${rect.left + offsetX}px`
			confetti.style.top = `${startY}px`

			confetti.style.setProperty("--confetti-delay", `${Math.random() * 0.5}s`)
			confetti.style.setProperty("--confetti-rotation", `${Math.random() * 360}deg`)

			overlay.appendChild(confetti)

			// アニメーション終了後に削除 (1.5s + 0.3s delay)
			setTimeout(() => {
				confetti.remove()
			}, 1800)
		}
	}
}
