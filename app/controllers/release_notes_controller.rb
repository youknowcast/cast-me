class ReleaseNotesController < ApplicationController
  before_action :authenticate_user!

  def index
    @release_notes = ReleaseNote.all
  end
end
