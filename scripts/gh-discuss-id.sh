gh api graphql -f query='
{
  repository(owner: "hrabid", name: "vopslab") {
    discussionCategories(first: 20) {
      nodes {
        id
        name
        slug
      }
    }
  }
}'
