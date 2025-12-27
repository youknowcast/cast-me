import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
	static targets = ["modal", "message"]

	declare readonly modalTarget: HTMLDialogElement
	declare readonly messageTarget: HTMLElement

	private deleteUrl = ""
	private deleteMethod = "delete"

	connect() {
		window.addEventListener('delete-confirm:open', this.open.bind(this) as any)
		this.modalTarget.addEventListener('click', this.handleBackdropClick.bind(this))
	}

	disconnect() {
		window.removeEventListener('delete-confirm:open', this.open.bind(this) as any)
		this.modalTarget.removeEventListener('click', this.handleBackdropClick.bind(this))
	}

	handleBackdropClick(event: MouseEvent) {
		if (event.target === this.modalTarget) {
			this.close()
		}
	}

	open(event: CustomEvent) {
		const { url, message, method } = event.detail
		this.deleteUrl = url
		this.deleteMethod = method || "delete"

		if (message) {
			this.messageTarget.textContent = message
		} else {
			this.messageTarget.textContent = "この項目を削除しますか？"
		}

		this.modalTarget.showModal()
	}

	close() {
		this.modalTarget.close()
	}

	confirm() {
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
		this.close()
	}
}
