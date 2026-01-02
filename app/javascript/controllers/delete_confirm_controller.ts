import { BaseActionSheetController } from "../lib/base_action_sheet_controller"

export default class extends BaseActionSheetController {
	static targets = ["modal", "message"]

	declare readonly messageTarget: HTMLElement

	private deleteUrl = ""
	private deleteMethod = "delete"

	get eventPrefix() {
		return 'delete-confirm'
	}

	onOpen(detail: any) {
		const { url, message, method } = detail
		this.deleteUrl = url
		this.deleteMethod = method || "delete"

		if (message) {
			this.messageTarget.textContent = message
		} else {
			this.messageTarget.textContent = "この項目を削除しますか？"
		}
	}

	/**
	 * backdrop クリック時は閉じるだけ（削除しない）
	 */
	protected handleBackdropClick(event: MouseEvent) {
		if (event.target === this.modalTarget) {
			this.close()
		}
	}

	onConfirm() {
		if (this.deleteUrl) {
			// Create and submit a form with the delete method
			const form = document.createElement('form')
			form.method = 'POST'
			form.action = this.deleteUrl
			form.style.display = 'none'

			// Add CSRF token
			const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
			if (csrfToken) {
				const csrfInput = document.createElement('input')
				csrfInput.type = 'hidden'
				csrfInput.name = 'authenticity_token'
				csrfInput.value = csrfToken
				form.appendChild(csrfInput)
			}

			// Add method override for DELETE
			const methodInput = document.createElement('input')
			methodInput.type = 'hidden'
			methodInput.name = '_method'
			methodInput.value = this.deleteMethod
			form.appendChild(methodInput)

			document.body.appendChild(form)
			form.submit()
		}
		return null // No event dispatch needed
	}
}
