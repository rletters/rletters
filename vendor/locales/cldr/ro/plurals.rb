# -*- encoding : utf-8 -*-
{ :'ro' => { i18n: { plural: { keys: [:one, :few, :other], rule: lambda { |n| n == 1 ? :one : n == 0 ? :few : :other } } } } }
