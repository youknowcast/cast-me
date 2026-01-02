require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#linkify_urls' do
    context 'with URLs containing scheme' do
      it 'converts http URL to clickable link' do
        text = 'Visit http://example.com for more info'
        result = helper.linkify_urls(text)
        expect(result).to include('<a href="http://example.com" target="_blank" rel="noopener noreferrer">http://example.com</a>')
        expect(result).to include('Visit')
        expect(result).to include('for more info')
      end

      it 'converts https URL to clickable link' do
        text = 'Check out https://example.com/path'
        result = helper.linkify_urls(text)
        expect(result).to include('<a href="https://example.com/path" target="_blank" rel="noopener noreferrer">https://example.com/path</a>')
      end

      it 'converts multiple URLs in text' do
        text = 'Visit https://example.com and http://test.com'
        result = helper.linkify_urls(text)
        expect(result).to include('<a href="https://example.com" target="_blank" rel="noopener noreferrer">https://example.com</a>')
        expect(result).to include('<a href="http://test.com" target="_blank" rel="noopener noreferrer">http://test.com</a>')
      end

      it 'handles URLs with query parameters' do
        text = 'Search at https://example.com/search?q=test&lang=en'
        result = helper.linkify_urls(text)
        expect(result).to include('href="https://example.com/search?q=test&amp;lang=en"')
        expect(result).to include('target="_blank"')
        expect(result).to include('rel="noopener noreferrer"')
      end

      it 'handles URLs with fragments' do
        text = 'Section https://example.com/page#section'
        result = helper.linkify_urls(text)
        expect(result).to include('href="https://example.com/page#section"')
      end
    end

    context 'with edge cases and malformed inputs' do
      it 'handles Wikipedia links with parentheses' do
        text = 'Visit https://en.wikipedia.org/wiki/Ruby_(programming_language)'
        result = helper.linkify_urls(text)
        expect(result).to include('<a href="https://en.wikipedia.org/wiki/Ruby_(programming_language)"')
      end

      it 'handles bracketed paths' do
        text = 'Check https://example.com/path[bracketed]'
        result = helper.linkify_urls(text)
        expect(result).to include('<a href="https://example.com/path[bracketed]"')
      end

      it 'handles URLs nested in parentheses' do
        text = 'Check (https://example.com/path/to/page)'
        result = helper.linkify_urls(text)
        expect(result).to include('(<a href="https://example.com/path/to/page"')
        expect(result).to end_with('</a>)')
      end

      it 'does not linkify malformed domains' do
        text = 'Invalid https://.com or https://-'
        result = helper.linkify_urls(text)
        expect(result).not_to include('<a href')
      end

      it 'handles URLs with ports' do
        text = 'Service at https://example.com:8080/api'
        result = helper.linkify_urls(text)
        expect(result).to include('<a href="https://example.com:8080/api"')
      end
    end

    context 'with URLs without scheme' do
      it 'does not convert scheme-less URLs' do
        text = 'Visit example.com for more'
        result = helper.linkify_urls(text)
        expect(result).not_to include('<a href')
        expect(result).to include('example.com')
      end

      it 'does not convert www URLs without scheme' do
        text = 'Go to www.example.com'
        result = helper.linkify_urls(text)
        expect(result).not_to include('<a href')
        expect(result).to include('www.example.com')
      end
    end

    context 'with trailing punctuation' do
      it 'excludes trailing period from link' do
        text = 'Visit https://example.com.'
        result = helper.linkify_urls(text)
        expect(result).to include('href="https://example.com"')
        expect(result).to end_with('</a>.')
      end

      it 'excludes trailing comma from link' do
        text = 'Sites: https://example.com, https://test.com'
        result = helper.linkify_urls(text)
        expect(result).to include('href="https://example.com"')
        expect(result).to include('</a>,')
      end

      it 'excludes trailing parenthesis and period from link' do
        text = 'Check (https://example.com).'
        result = helper.linkify_urls(text)
        expect(result).to include('href="https://example.com"')
        expect(result).to include('</a>).')
      end

      it 'excludes trailing exclamation from link' do
        text = 'Amazing site https://example.com!'
        result = helper.linkify_urls(text)
        expect(result).to include('href="https://example.com"')
        expect(result).to end_with('</a>!')
      end

      it 'excludes trailing question mark from link' do
        text = 'Did you see https://example.com?'
        result = helper.linkify_urls(text)
        expect(result).to include('href="https://example.com"')
        expect(result).to end_with('</a>?')
      end
    end

    context 'with newlines' do
      it 'preserves newlines as <br> tags' do
        text = "Line 1\nLine 2\nLine 3"
        result = helper.linkify_urls(text)
        expect(result).to include('Line 1<br>Line 2<br>Line 3')
      end

      it 'preserves newlines and converts URLs' do
        text = "Visit https://example.com\nFor more info"
        result = helper.linkify_urls(text)
        expect(result).to include('<a href="https://example.com"')
        expect(result).to include('<br>')
      end
    end

    context 'with XSS prevention' do
      it 'escapes HTML tags in text' do
        text = '<script>alert("xss")</script> Visit https://example.com'
        result = helper.linkify_urls(text)
        expect(result).to include('&lt;script&gt;')
        expect(result).not_to include('<script>')
        expect(result).to include('<a href="https://example.com"')
      end

      it 'escapes special characters' do
        text = 'Test & check <b>https://example.com</b>'
        result = helper.linkify_urls(text)
        expect(result).to include('&amp;')
        expect(result).to include('&lt;b&gt;')
        expect(result).to include('<a href="https://example.com"')
      end

      it 'escapes quotes in surrounding text' do
        text = 'He said "Visit https://example.com"'
        result = helper.linkify_urls(text)
        expect(result).to include('&quot;Visit')
        expect(result).to include('<a href="https://example.com"')
      end
    end

    context 'with empty or nil input' do
      it 'returns empty string for nil' do
        result = helper.linkify_urls(nil)
        expect(result).to eq('')
        expect(result).to be_html_safe
      end

      it 'returns empty string for empty string' do
        result = helper.linkify_urls('')
        expect(result).to eq('')
        expect(result).to be_html_safe
      end

      it 'returns empty string for whitespace-only string' do
        result = helper.linkify_urls('   ')
        expect(result).to eq('')
        expect(result).to be_html_safe
      end
    end

    context 'with plain text without URLs' do
      it 'returns escaped text without modifications' do
        text = 'This is plain text without any URLs'
        result = helper.linkify_urls(text)
        expect(result).to eq('This is plain text without any URLs')
        expect(result).to be_html_safe
      end
    end
  end
end
