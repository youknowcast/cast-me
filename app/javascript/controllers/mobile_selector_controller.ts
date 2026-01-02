import { BaseActionSheetController } from "../lib/base_action_sheet_controller"

export default class extends BaseActionSheetController {
	static targets = ["modal", "input", "triggerText", "optionCheck"]

	declare readonly inputTarget: HTMLInputElement
	declare readonly triggerTextTarget: HTMLElement
	declare readonly optionCheckTargets: HTMLElement[]

	get eventPrefix() {
		return 'mobile-selector'
	}

	connect() {
		super.connect()
		this.updateChecks()
	}

	onOpen(_detail: any) {
		// No special initialization needed
	}

	onConfirm() {
		return null // No event dispatch needed
	}

	select(event: CustomEvent & { params: { value: string, text: string } }) {
		const { value, text } = event.params
		this.inputTarget.value = value
		this.triggerTextTarget.textContent = text

		this.updateChecks()
		this.close()

		// Dispatch change event to the hidden input so other listeners can react
		this.inputTarget.dispatchEvent(new Event('change', { bubbles: true }))
	}

	private updateChecks() {
		const currentValue = this.inputTarget.value
		this.optionCheckTargets.forEach(target => {
			const value = target.dataset.value
			if (value === currentValue) {
				target.classList.remove('opacity-0')
				target.classList.add('text-primary')
			} else {
				target.classList.remove('text-primary')
				target.classList.add('opacity-0')
			}
		})
	}
}
