import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
	static targets = ["modal"]
	static values = { modalId: String }

	declare readonly modalTarget: HTMLDialogElement
	declare readonly hasModalTarget: boolean
	declare readonly modalIdValue: string

	openModal() {
		const modal = document.getElementById(this.modalIdValue) as HTMLDialogElement
		modal?.showModal()
	}

	closeModal() {
		const modal = document.getElementById(this.modalIdValue) as HTMLDialogElement
		modal?.close()
	}

	submit(_event: Event) {
		// フォーム送信後にモーダルを閉じる
		this.closeModal()
	}
}
