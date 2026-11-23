import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
	static values = {
		date: String,
		baseUrl: String
	}

	declare dateValue: string
	declare baseUrlValue: string

	open() {
		window.dispatchEvent(new CustomEvent('monthpicker:open', {
			detail: {
				date: this.dateValue,
				trigger: this.element,
				baseUrl: this.baseUrlValue
			}
		}))
	}
}
