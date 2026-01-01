import { Controller } from "@hotwired/stimulus"

/**
 * Regular Task Controller
 * 定型タスクの選択と登録アイコンのトグルを管理
 */
export default class extends Controller {
	static targets = ["titleInput", "registerIcon", "registerInput", "selectModal", "selectList"]

	declare titleInputTarget: HTMLInputElement
	declare registerIconTarget: HTMLElement
	declare registerInputTarget: HTMLInputElement
	declare selectModalTarget: HTMLDialogElement
	declare selectListTarget: HTMLElement
	declare hasSelectModalTarget: boolean
	declare hasSelectListTarget: boolean

	// クイック選択ボタンクリック時 - タイトルにコピー
	quickSelect(event: Event) {
		const target = event.currentTarget as HTMLElement
		const title = target.dataset.regularTaskTitle
		if (title && this.titleInputTarget) {
			this.titleInputTarget.value = title
			this.titleInputTarget.focus()
		}
	}

	// 登録アイコンのトグル
	toggleRegister() {
		const isActive = this.registerInputTarget.value === "true"
		this.registerInputTarget.value = isActive ? "false" : "true"

		if (isActive) {
			this.registerIconTarget.classList.remove("text-primary", "bg-primary/10")
			this.registerIconTarget.classList.add("text-gray-400")
		} else {
			this.registerIconTarget.classList.add("text-primary", "bg-primary/10")
			this.registerIconTarget.classList.remove("text-gray-400")
		}
	}

	// select モーダルを開く
	openSelect() {
		if (this.hasSelectModalTarget) {
			this.selectModalTarget.showModal()
		}
	}

	// select モーダルを閉じる
	closeSelect() {
		if (this.hasSelectModalTarget) {
			this.selectModalTarget.close()
		}
	}

	// select から選択時
	selectFromList(event: Event) {
		const target = event.currentTarget as HTMLElement
		const title = target.dataset.regularTaskTitle
		if (title && this.titleInputTarget) {
			this.titleInputTarget.value = title
			this.titleInputTarget.focus()
		}
		this.closeSelect()
	}
}
