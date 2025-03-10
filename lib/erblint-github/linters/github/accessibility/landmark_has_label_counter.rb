# frozen_string_literal: true

require_relative "../../custom_helpers"

module ERBLint
  module Linters
    module GitHub
      module Accessibility
        class LandmarkHasLabelCounter < Linter
          include ERBLint::Linters::CustomHelpers
          include LinterRegistry

          LANDMARK_ROLES = %w[complementary navigation region search].freeze
          LANDMARK_TAGS = %w[aside nav section].freeze
          MESSAGE = "Landmark elements should have an aria-label attribute, or aria-labelledby if a heading elements exists in the landmark."
          ROLE_TAG_MAPPING = { "complementary" => "aside", "navigation" => "nav", "region" => "section" }.freeze

          def get_additional_message(tag, roles)
            role_matched = (roles & ROLE_TAG_MAPPING.keys).first
            if role_matched
              tag_matched = ROLE_TAG_MAPPING[role_matched]

              if tag.name == tag_matched
                "The <#{tag_matched}> element will automatically communicate a role of '#{role_matched}'. You can safely drop the role attribute."
              else
                replace_message = if tag.name == "div"
                                    "If possible replace this tag with a <#{tag_matched}>."
                                  else
                                    "Wrapping this element in a <#{tag_matched}> and setting a label on it is reccomended."
                                  end

                "The <#{tag_matched}> element will automatically communicate a role of '#{role_matched}'. #{replace_message}"
              end
            elsif roles.include?("search") && tag.name != "form"
              "The 'search' role works best when applied to a <form> element. If possible replace this tag with a <form>."
            end
          end

          def run(processed_source)
            tags(processed_source).each do |tag|
              next if tag.closing?

              possible_roles = possible_attribute_values(tag, "role")
              next unless LANDMARK_TAGS.include?(tag.name) && (possible_roles & LANDMARK_ROLES).empty?
              next if tag.attributes["aria-label"]&.value&.present? || tag.attributes["aria-labelledby"]&.value&.present?

              message = get_additional_message(tag, possible_roles)
              if message
                generate_offense(self.class, processed_source, tag, "#{MESSAGE}\n#{message}")
              else
                generate_offense(self.class, processed_source, tag)
              end
            end

            counter_correct?(processed_source)
          end

          def autocorrect(processed_source, offense)
            return unless offense.context

            lambda do |corrector|
              if processed_source.file_content.include?("erblint:counter #{simple_class_name}")
                # update the counter if exists
                corrector.replace(offense.source_range, offense.context)
              else
                # add comment with counter if none
                corrector.insert_before(processed_source.source_buffer.source_range, "#{offense.context}\n")
              end
            end
          end
        end
      end
    end
  end
end
