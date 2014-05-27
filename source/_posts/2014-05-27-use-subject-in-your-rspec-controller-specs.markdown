---
layout: post
title:  Use subject in your RSpec controller specs
---

## Use subject in RSpec controller specs

This is a very common issue I see with RSpec controller specs.

### Bad

```ruby
before do
  get :show
end

it 'returns 200' do
  expect(response.code).to eq('200')
end
```

### Good

```ruby
subject do
  get :show
  response
end

it 'returns 200' do
  expect(subject.code).to eq('200')
end
```

### Why is the first method preferable?

* It's more semantic. The request is not a prerequesite for the thing you're
  testing. It *is* the thing you're testing.

* It allows you to have nested `before` blocks to test subconditions:

  ```ruby
  before do
    get :show
  end

  it 'responds 400' do
    expect(response.code).to eq('400')
  end

  context 'as admin' do
    before do
      sign_in(admin)
    end

    it 'responds 200' do
      expect(response.code).to eq('200')
    end
  end
  ```

  The second test will fail! `before` blocks are executed in the order
  they're declared, so you will perform the `get`, receive `400`, and
  then sign in as an admin.

  Instead:

  ```ruby
  subject do
    get :show
    response
  end

  context 'as admin' do
    before do
      sign_in(admin)
    end

    it 'responds 200' do
      expect(subject.code).to eq('200')
    end
  end
  ```

  `subject` blocks are executed lazily, so that will work!
