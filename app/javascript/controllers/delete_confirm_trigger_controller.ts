import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
	static values = {
		url: String,
		message: String,
		method: { type: String, default: "delete" }
	}

	declare urlValue: string
	declare messageValue: string
	declare methodValue: string

	open(event: Event) {
		event.preventDefault()
		event.stopPropagation()

		window.dispatchEvent(new CustomEvent('delete-confirm:open', {
			detail: {
				url: this.urlValue,
				message: this.messageValue,
				method: this.methodValue
			}
		}))
	}
}
