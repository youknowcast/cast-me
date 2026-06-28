import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

import MealFoodController from "../../../app/javascript/controllers/meal_food_controller"

const flush = () => new Promise(resolve => setTimeout(resolve, 0))

const html = `
  <div data-controller="meal-food">
    <button id="quick" type="button" data-action="meal-food#quickSelect" data-food-name="ラーメン"></button>
    <div data-meal-food-target="chips"></div>
    <input data-meal-food-target="input" />
    <button id="add" type="button" data-action="meal-food#addFromInput"></button>
  </div>
`

describe("meal-food controller", () => {
  let application: Application

  beforeEach(async () => {
    HTMLDialogElement.prototype.showModal = vi.fn()
    HTMLDialogElement.prototype.close = vi.fn()
    document.body.innerHTML = html
    application = Application.start()
    application.register("meal-food", MealFoodController)
    await flush()
  })

  afterEach(async () => {
    application.stop()
    document.body.innerHTML = ""
    await flush()
    vi.restoreAllMocks()
  })

  const names = () =>
    Array.from(document.querySelectorAll<HTMLInputElement>('input[name="meal[food_names][]"]')).map(i => i.value)

  it("adds a chip with a hidden input on quick select", async () => {
    document.querySelector<HTMLButtonElement>("#quick")!.click()
    await flush()
    expect(names()).toEqual(["ラーメン"])
  })

  it("adds from text input and clears it", async () => {
    const input = document.querySelector<HTMLInputElement>('[data-meal-food-target="input"]')!
    input.value = "カレー"
    document.querySelector<HTMLButtonElement>("#add")!.click()
    await flush()
    expect(names()).toEqual(["カレー"])
    expect(input.value).toBe("")
  })

  it("does not add duplicates", async () => {
    const btn = document.querySelector<HTMLButtonElement>("#quick")!
    btn.click()
    btn.click()
    await flush()
    expect(names()).toEqual(["ラーメン"])
  })

  it("removes a chip", async () => {
    document.querySelector<HTMLButtonElement>("#quick")!.click()
    await flush()
    document.querySelector<HTMLButtonElement>('[data-action="meal-food#removeFood"]')!.click()
    await flush()
    expect(names()).toEqual([])
  })
})
