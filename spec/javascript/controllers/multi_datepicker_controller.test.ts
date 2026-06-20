import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

import DatepickerConnectorController from "../../../app/javascript/controllers/datepicker_connector_controller"
import DatepickerController from "../../../app/javascript/controllers/datepicker_controller"
import MultiDatepickerConnectorController from "../../../app/javascript/controllers/multi_datepicker_connector_controller"

const flush = () => new Promise(resolve => setTimeout(resolve, 0))

describe("multi-date plan picker", () => {
	let application: Application

	beforeEach(async () => {
		vi.spyOn(console, "log").mockImplementation(() => undefined)
		vi.stubGlobal("requestAnimationFrame", (callback: FrameRequestCallback) => {
			callback(0)
			return 1
		})
		Element.prototype.scrollIntoView = vi.fn()
		HTMLDialogElement.prototype.showModal = vi.fn()
		HTMLDialogElement.prototype.close = vi.fn()

		document.body.innerHTML = html
		application = Application.start()
		application.register("datepicker", DatepickerController)
		application.register("datepicker-connector", DatepickerConnectorController)
		application.register("multi-datepicker-connector", MultiDatepickerConnectorController)
		await flush()
	})

	afterEach(async () => {
		application.stop()
		document.body.innerHTML = ""
		await flush()
		vi.restoreAllMocks()
		vi.unstubAllGlobals()
	})

	it("adds and removes dates while retaining at least one selection", async () => {
		click("#open-multiple")
		await flush()

		expect(selectedCount()).toBe("1日")
		expect(day("2026-06-20").classList.contains("bg-blue-500")).toBe(true)

		day("2026-06-21").click()
		expect(selectedCount()).toBe("2日")
		expect(day("2026-06-21").classList.contains("bg-blue-500")).toBe(true)

		day("2026-06-20").click()
		expect(selectedCount()).toBe("1日")
		expect(day("2026-06-20").classList.contains("bg-blue-500")).toBe(false)

		day("2026-06-21").click()
		expect(selectedCount()).toBe("1日")
		expect(day("2026-06-21").classList.contains("bg-blue-500")).toBe(true)
	})

	it("writes every confirmed date to plan hidden inputs", async () => {
		click("#open-multiple")
		await flush()
		day("2026-06-21").click()
		click("#confirm-date")
		await flush()

		expect(planDates()).toEqual(["2026-06-20", "2026-06-21"])
		expect(document.querySelector("[data-multi-datepicker-connector-target='triggerText']")?.textContent).toBe("2日選択")
		expect(document.querySelector("[data-multi-datepicker-connector-target='datesText']")?.textContent)
			.toBe("2026/06/20、2026/06/21")
	})

	it("keeps the existing single-date picker behavior", async () => {
		click("#open-single")
		await flush()
		day("2026-06-22").click()
		click("#confirm-date")
		await flush()

		const input = document.querySelector<HTMLInputElement>("[data-datepicker-connector-target='input']")
		expect(input?.value).toBe("2026-06-22")
		expect(document.querySelector("[data-datepicker-connector-target='triggerText']")?.textContent).toBe("2026/06/22")
		const count = document.querySelector("[data-datepicker-target='selectedCount']")
		expect(count?.classList.contains("hidden")).toBe(true)
	})

	it("does not duplicate confirmation listeners after reconnecting", async () => {
		const connector = document.querySelector<HTMLElement>("[data-controller='multi-datepicker-connector']")!
		const inputs = connector.querySelector<HTMLElement>("[data-multi-datepicker-connector-target='inputs']")!
		const replaceChildren = vi.spyOn(inputs, "replaceChildren")

		connector.remove()
		await flush()
		document.body.prepend(connector)
		await flush()

		window.dispatchEvent(new CustomEvent("datepicker:confirmed", {
			detail: { dates: ["2026-06-23"], trigger: connector }
		}))

		expect(replaceChildren).toHaveBeenCalledOnce()
		expect(planDates()).toEqual(["2026-06-23"])
	})

	function click(selector: string) {
		const element = document.querySelector<HTMLElement>(selector)
		if (!element) throw new Error(`Missing element: ${selector}`)
		element.click()
	}

	function day(date: string) {
		const element = document.querySelector<HTMLButtonElement>(`[data-date='${date}']`)
		if (!element) throw new Error(`Missing date: ${date}`)
		return element
	}

	function selectedCount() {
		return document.querySelector("[data-datepicker-target='selectedCount']")?.textContent
	}

	function planDates() {
		return Array.from(document.querySelectorAll<HTMLInputElement>("input[name='plan[dates][]']"))
			.map(input => input.value)
	}
})

const html = `
	<div data-controller="multi-datepicker-connector">
		<div data-multi-datepicker-connector-target="inputs">
			<input type="hidden" name="plan[dates][]" value="2026-06-20">
		</div>
		<button id="open-multiple" data-action="multi-datepicker-connector#open" type="button">
			<span data-multi-datepicker-connector-target="triggerText"></span>
		</button>
		<p data-multi-datepicker-connector-target="datesText"></p>
	</div>

	<div data-controller="datepicker-connector">
		<input type="hidden" value="2026-06-20" data-datepicker-connector-target="input">
		<button id="open-single" data-action="datepicker-connector#open" type="button">
			<span data-datepicker-connector-target="triggerText"></span>
		</button>
	</div>

	<div data-controller="datepicker">
		<dialog data-datepicker-target="modal">
			<h3 data-datepicker-target="headerTitle"></h3>
			<span class="hidden" data-datepicker-target="selectedCount"></span>
			<div data-datepicker-target="loader"></div>
			<div data-datepicker-target="scrollArea"></div>
			<button id="confirm-date" data-action="datepicker#confirm" type="button">確定</button>
		</dialog>
	</div>
`
