# frozen_string_literal: true
module Tolk
  class LocalesController < Tolk::ApplicationController
    before_action :find_locale, only: [:show, :all, :completed, :update, :updated]
    before_action :ensure_no_primary_locale, only: [:all, :update, :show, :updated]

    helper_method :category_known?

    def index
      # HACK: allows to select primary locale
      # @locales = Tolk::Locale.secondary_locales.sort_by(&:language_name)
      @locales = Tolk::Locale.all.sort_by(&:language_name)
    end

    def show
      respond_to do |format|
        format.html do
          @phrases = @locale.phrases_without_translation(params[pagination_param])
            .where(category: params[:category])
            .order(:key)
        end

        format.atom { @phrases = @locale.phrases_without_translation(params[pagination_param]).order(:key).per(50) }

        format.yaml do
          data = @locale.to_hash
          render text: Tolk::YAML.dump(data)
        end
      end
    end

    def update
      @locale.translations_attributes = translation_params
      @locale.save
      redirect_to request.referrer
    end

    def all
      @phrases = Tolk::Phrase.where(category: params[:category])
        .order(:key)
        .public_send(pagination_method, params[pagination_param])
      translations = Tolk::Translation.where(locale: @locale, phrase_id: @phrases.select(:id))
      @phrases.each { |p| p.translation = translations.find { |t| t.phrase_id == p.id } }
      render :show
    end

    def completed
      @phrases = Tolk::Phrase.joins(:translations)
        .with_category(params[:category])
        .merge(Tolk::Translation.where(locale: @locale))
        .order(:key)
        .public_send(pagination_method, params[pagination_param])
      translations = Tolk::Translation.where(locale: @locale, phrase_id: @phrases.select(:id))
      @phrases.each { |p| p.translation = translations.find { |t| t.phrase_id == p.id } }
      render :show
    end

    def updated
      @phrases = @locale.phrases_with_updated_translation(params[pagination_param])
      render :all
    end

    def create
      Tolk::Locale.create!(locale_params)
      redirect_to action: :index
    end

    def dump_all
      Tolk::Locale.dump_all
      redirect_to request.referrer
    end

    def stats
      @locales = Tolk::Locale.secondary_locales.sort_by(&:language_name)

      respond_to do |format|
        format.json do
          stats = @locales.collect do |locale|
            [locale.name, {
              missing: locale.count_phrases_without_translation,
              updated: locale.count_phrases_with_updated_translation,
              updated_at: locale.updated_at
            }]
          end
          render json: Hash[stats]
        end
      end
    end

    def sync
      I18n.backend = I18n::Backend::Simple.new
      I18n.backend.reload!
      Tolk::Locale.sync!
      I18n.backend = I18n::Backend::ActiveRecord.new
      I18n.backend.reload!
      redirect_to root_path
    end

    private

    def find_locale
      @locale = Tolk::Locale.where("UPPER(name) = UPPER(?)", params[:id]).first!
    end

    def locale_params
      params.require(:tolk_locale).permit(:name)
    end

    def translation_params
      params.permit(translations: [:id, :phrase_id, :locale_id, :text])[:translations]
    end

    def category_known?
      params[:category].present?
    end
  end
end
