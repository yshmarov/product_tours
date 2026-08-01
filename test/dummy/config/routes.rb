# frozen_string_literal: true

Rails.application.routes.draw do
  mount_product_tours at: "/product_tours"
  get "sample", to: "sample#show"
end
