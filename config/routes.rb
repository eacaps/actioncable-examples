Rails.application.routes.draw do
  mount ActionCable.server => '/ws'

  resource  :session
  resources :examples

  resources :messages do
    resources :comments
  end

  root 'examples#index'
end
