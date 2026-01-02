import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
	static targets = ["input", "form"]

	selectFile() {
		this.inputTarget.click()
	}

	submit() {
		this.formTarget.submit()
	}
}
